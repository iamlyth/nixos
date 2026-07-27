{ lib, config, pkgs, inputs, ... }:
with lib;
let
  cfg = config.pimodule;

  # Nix-pinned baseline extensions (context-mode + pi-subagents). To update:
  # scripts/update-deps.sh context-mode "@tintinweb/pi-subagents"
  #
  # Built with pi.nix's own nixpkgs, not ours: context-mode ships the native
  # better-sqlite3 addon, which must match the node ABI that pi itself is
  # wrapped with.
  # NOTE: scripts/update-deps.sh regenerates npmDepsHash from a derivation
  # built out of the pin's dir/nixpkgs/fetcherVersion fields in pins.json;
  # if you change this derivation's shape, update those fields to match.
  pins = importJSON ./pins.json;
  piPkgs = inputs.pi-nix.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  piExtensionDeps = piPkgs.buildNpmPackage {
    pname = "pi-extensions-deps";
    version = "2026-07-14";
    src = ./pi-extensions-deps;
    npmDepsHash = pins."pi-extensions".npmDepsHash;
    # Fetcher v1 skips lock entries flagged "peer": true (the pi packages that
    # pi-subagents peer-depends on), which npm ci then can not find offline.
    # v2 fetches them.
    npmDepsFetcherVersion = 2;
    nativeBuildInputs = [ piPkgs.python3 ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  # models.json contents. The pi-nix module installs this into
  # ~/.pi/agent/models.json (only if one is not already present).
  modelsFile = pkgs.writeText "pi-models.json" (builtins.toJSON {
    providers = {
      ollama = {
        baseUrl = "http://localhost:11434/v1";
        api = "openai-completions";
        apiKey = "ollama";
        models = [
          { id = "gemma4:31b"; }
        ];
      };
    };
  });

  # ---- Jail permission set shared by both instances ----
  # General-purpose development baseline. add-pkg-deps exposes each package's
  # binaries and runtime closure, but does not expose privileged host sockets
  # (notably the Nix daemon, Docker, or an SSH agent).
  sharedJailPkgs = with pkgs; [
    # Shell, source control, and navigation
    bash coreutils diffutils fd findutils gawk git gnugrep gnused jq
    ripgrep vim which tree

    # Network access and remote Git
    cacert curl wget openssh netcat-openbsd

    # Archives, patches, and file inspection
    file patch gnutar gzip bzip2 xz zip unzip

    # Language runtimes and package managers
    nodejs bun pnpm yarn python313 uv

    # Native compilation and build systems
    gcc gnumake cmake ninja meson pkg-config

    # Data and diagnostics
    sqlite procps lsof strace gdb

    # Nix and repository quality tools. The Nix CLI is available for parsing
    # and local operations, but the daemon socket remains intentionally absent.
    nix nixfmt-rfc-style statix deadnix shellcheck shfmt
  ];

  # ---- Instance 1: pi (primary coding agent) ----
  # Same config as before: context-mode + pi-subagents, gemma4:31b,
  # persisted home "pi-coder", vim editor.
  piMain = inputs.pi-nix.lib.mkCodingAgent {
    inherit pkgs;
    modules = [{
      config.pi.coding-agent = {
        # DECLARATIVE baseline: these are pinned from the nix store and injected
        # via --extension/--skill on every launch. The entry points come from
        # each package's "pi" field in package.json.
        #
        # You can still EXPERIMENT imperatively: `pi install npm:...` drops an
        # extension in ~/.pi/agent and pi auto-discovers it alongside these pins.
        # To keep one, promote it to a pin: `pi uninstall <name>`, add it to
        # pi-extensions-deps/package.json + this list, run scripts/update-deps.sh,
        # rebuild. Never leave the same extension both pinned here AND installed
        # in ~/.pi/agent, or pi loads it twice (conflict diagnostics).
        extensions = [
          "${piExtensionDeps}/node_modules/context-mode/build/adapters/pi/extension.js"
          "${piExtensionDeps}/node_modules/@tintinweb/pi-subagents/src/index.ts"
        ];
        skills = [ "${piExtensionDeps}/node_modules/context-mode/skills" ];

        # bubblewrap isolation via jail.nix. The module always binds pi's agent
        # dir (~/.pi/agent) read-write itself, so it is intentionally absent from
        # this list; persist-home keeps the imperative npm install root
        # (~/.local/share/pi/npm) across launches so `pi install` experiments
        # survive relaunches.
        jail.enable = true;
        jail.permissions = combinators: with combinators; [
          network
          no-new-session
          (persist-home "pi-coder")
          (set-env "EDITOR" "vim")
          (set-env "VISUAL" "vim")
          (add-pkg-deps sharedJailPkgs)
          # WSL: /etc/resolv.conf is a symlink to /mnt/wsl/resolv.conf. jail.nix
          # recreates the symlink but only bind-mounts targets under /nix/store,
          # so inside the jail the link dangles, glibc falls back to
          # 127.0.0.1:53, and every lookup fails with EAI_AGAIN (this breaks
          # OAuth login, which resolves platform.claude.com). Bind the target so
          # the link resolves. Uses -try because the path is absent on non-WSL
          # hosts, where this becomes a no-op.
          (unsafe-add-raw-args "--ro-bind-try /mnt/wsl/resolv.conf /mnt/wsl/resolv.conf")
          (unsafe-add-raw-args "--dir /usr/bin --symlink ${pkgs.coreutils}/bin/env /usr/bin/env")
          (unsafe-add-raw-args ''--bind "$PWD" "/workspace/$(basename "$PWD")"'')
          (unsafe-add-raw-args ''--chdir "/workspace/$(basename "$PWD")"'')
        ];

        models = modelsFile;
        settings = {
          defaultProvider = "ollama";
          defaultModel = "gemma4:31b";
        };
      };
    }];
  };

  # ---- Instance 2: pi2 (secondary, separately configured) ----
  # Separate persisted home ("pi2"), separate agent dir (~/.pi/agent2), and a
  # per-host provider/model via pimodule.pi2.{provider,model}. Extend/modify
  # this block to diverge further (different extensions, jail packages, rules).
  pi2 = inputs.pi-nix.lib.mkCodingAgent {
    inherit pkgs;
    modules = [{
      config.pi.coding-agent = {
        extensions = [
          "${piExtensionDeps}/node_modules/context-mode/build/adapters/pi/extension.js"
          "${piExtensionDeps}/node_modules/@tintinweb/pi-subagents/src/index.ts"
        ];
        skills = [ "${piExtensionDeps}/node_modules/context-mode/skills" ];

        # Separate agent config directory so settings/models don't collide
        # with the primary instance. CONTEXT_MODE_DATA_DIR isolates the
        # context-mode session DB from pi's — context-mode hardcodes its
        # session store under ~/.pi/context-mode/sessions/ using homedir(),
        # NOT PI_CODING_AGENT_DIR, so without this override both instances
        # would share the same database and leak conversation history.
        # Use ~/.pi2 as context-mode's data root (sessions land at
        # ~/.pi2/context-mode/sessions/), keeping it separate from the
        # agent config at ~/.pi/agent2.
        environment = {
          PI_CODING_AGENT_DIR.value = "${config.home.homeDirectory}/.pi/agent2";
          CONTEXT_MODE_DATA_DIR.value = "${config.home.homeDirectory}/.pi2";
        };

        jail.enable = true;
        jail.permissions = combinators: with combinators; [
          network
          no-new-session
          (persist-home "pi2")
          (set-env "EDITOR" "vim")
          (set-env "VISUAL" "vim")
          (add-pkg-deps sharedJailPkgs)
          # WSL: /etc/resolv.conf is a symlink to /mnt/wsl/resolv.conf. jail.nix
          # recreates the symlink but only bind-mounts targets under /nix/store,
          # so inside the jail the link dangles, glibc falls back to
          # 127.0.0.1:53, and every lookup fails with EAI_AGAIN (this breaks
          # OAuth login, which resolves platform.claude.com). Bind the target so
          # the link resolves. Uses -try because the path is absent on non-WSL
          # hosts, where this becomes a no-op.
          (unsafe-add-raw-args "--ro-bind-try /mnt/wsl/resolv.conf /mnt/wsl/resolv.conf")
          (unsafe-add-raw-args "--dir /usr/bin --symlink ${pkgs.coreutils}/bin/env /usr/bin/env")
          (unsafe-add-raw-args ''--bind "$PWD" "/workspace/$(basename "$PWD")"'')
          (unsafe-add-raw-args ''--chdir "/workspace/$(basename "$PWD")"'')
        ];

        models = modelsFile;
        # Provider/model come from pimodule.pi2.{provider,model} so each host
        # can point this instance at whatever it has credentials for.
        settings = {
          defaultProvider = cfg.pi2.provider;
          defaultModel = cfg.pi2.model;
        };
      };
    }];
  };

  # mkCodingAgent always produces a binary named "pi". Rename the second
  # instance so both are available side by side on PATH.
  pi2Renamed = pkgs.writeShellScriptBin "pi2" ''
    exec ${pi2.package}/bin/pi "$@"
  '';
  # ---- Per-instance options ----
  # Each instance is independently toggleable so hosts can pick which to use.
  # E.g. desktop runs both, laptop runs only pi2 (API keys only).
in
{
  options.pimodule = {
    enable = mkEnableOption "pi coding agent (via mkCodingAgent)";

    pi = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the primary pi instance (local ollama, gemma4:31b).";
      };
    };

    pi2 = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the secondary pi2 instance (hosted provider).";
      };

      provider = mkOption {
        type = types.str;
        default = "openai-codex";
        example = "anthropic";
        description = ''
          Provider written to pi2's settings as defaultProvider. Built-in
          OAuth/API-key providers (for example "anthropic", "openai-codex")
          work as-is; anything else must be declared in the models file.
        '';
      };

      model = mkOption {
        type = types.str;
        default = "gpt-5.6-terra";
        example = "claude-opus-5";
        description = ''
          Model id written to pi2's settings as defaultModel. Must be a model
          the chosen provider serves.
        '';
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      optional cfg.pi.enable piMain.package    # → `pi` command  (primary, gemma4:31b, ~/.pi/agent)
      ++ optional cfg.pi2.enable pi2Renamed;   # → `pi2` command  (secondary, per-host provider, ~/.pi/agent2)
  };
}