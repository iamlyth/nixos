{
  lib,
  config,
  pkgs,
  inputs,
  ...
}:
with lib;
let
  cfg = config.pimodule;
  prepareWorkspace = ''
    pi_workspace_fail() {
      printf 'pi jail: %s\n' "$*" >&2
      exit 1
    }

    pi_workspace_sensitive() {
      case "$1" in
        / | /boot | /boot/* | /dev | /dev/* | /etc | /etc/* | /nix | /nix/* | \
          /proc | /proc/* | /root | /root/* | /run | /run/* | /sys | /sys/* | \
          /tmp | /tmp/* | /usr | /usr/* | /var | /var/* | /mnt | /mnt/* | \
          /media | /media/* | /opt | /opt/* | /srv | /srv/* | \
          "$pi_host_home" | "$pi_host_home"/.cache | "$pi_host_home"/.cache/* | \
          "$pi_host_home"/.config | "$pi_host_home"/.config/* | \
          "$pi_host_home"/.gnupg | "$pi_host_home"/.gnupg/* | \
          "$pi_host_home"/.local | "$pi_host_home"/.local/* | \
          "$pi_host_home"/.password-store | "$pi_host_home"/.password-store/* | \
          "$pi_host_home"/.ssh | "$pi_host_home"/.ssh/*)
          return 0
          ;;
      esac
      return 1
    }

    pi_host_home=${escapeShellArg config.home.homeDirectory}
    pi_launch_dir="$(${pkgs.coreutils}/bin/realpath -e -- "$PWD" 2>/dev/null)" || \
      pi_workspace_fail "cannot canonicalize launch directory: $PWD"
    [ -d "$pi_launch_dir" ] || \
      pi_workspace_fail "launch path is not a directory: $pi_launch_dir"
    pi_workspace_sensitive "$pi_launch_dir" && \
      pi_workspace_fail "refusing sensitive launch directory: $pi_launch_dir"

    pi_project_dir="$(${pkgs.git}/bin/git -C "$pi_launch_dir" rev-parse --show-toplevel 2>/dev/null)" || \
      pi_workspace_fail "launch directory is not inside a Git worktree: $pi_launch_dir"
    pi_project_dir="$(${pkgs.coreutils}/bin/realpath -e -- "$pi_project_dir" 2>/dev/null)" || \
      pi_workspace_fail "cannot canonicalize Git worktree root: $pi_project_dir"
    [ -d "$pi_project_dir" ] || \
      pi_workspace_fail "Git worktree root is not a directory: $pi_project_dir"
    pi_workspace_sensitive "$pi_project_dir" && \
      pi_workspace_fail "refusing sensitive Git worktree root: $pi_project_dir"

    pi_git_common_dir="$(${pkgs.git}/bin/git -C "$pi_project_dir" rev-parse --git-common-dir 2>/dev/null)" || \
      pi_workspace_fail "cannot resolve Git metadata for: $pi_project_dir"
    case "$pi_git_common_dir" in
      /*) ;;
      *) pi_git_common_dir="$pi_project_dir/$pi_git_common_dir" ;;
    esac
    pi_git_common_dir="$(${pkgs.coreutils}/bin/realpath -e -- "$pi_git_common_dir" 2>/dev/null)" || \
      pi_workspace_fail "cannot canonicalize Git metadata: $pi_git_common_dir"
    case "$pi_git_common_dir" in
      "$pi_project_dir" | "$pi_project_dir"/*) ;;
      *) pi_workspace_fail "Git metadata is outside the project (linked worktrees and submodules are unsupported): $pi_git_common_dir" ;;
    esac

    case "$pi_launch_dir" in
      "$pi_project_dir" | "$pi_project_dir"/*) ;;
      *) pi_workspace_fail "canonical launch directory escaped its Git worktree: $pi_launch_dir" ;;
    esac

    pi_project_name="$(${pkgs.coreutils}/bin/basename -- "$pi_project_dir")" || \
      pi_workspace_fail "cannot derive project name from: $pi_project_dir"
    case "$pi_project_name" in
      "" | "." | "..") pi_workspace_fail "unsafe project name: $pi_project_name" ;;
    esac

    PI_JAIL_WORKSPACE_SOURCE="$pi_project_dir"
    PI_JAIL_WORKSPACE_DESTINATION="/workspace/$pi_project_name"
    export PI_JAIL_WORKSPACE_SOURCE PI_JAIL_WORKSPACE_DESTINATION
  '';
  sshRunnerSource = "${config.home.homeDirectory}/.config/pi2-ssh-runner";

  # Nix-pinned baseline extensions (context-mode + pi-subagents + rpiv-voice).
  # To update:
  # scripts/update-deps.sh context-mode "@juicesharp/rpiv-voice" "@tintinweb/pi-subagents"
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

  # Per-instance models.json contents. Both providers are listed so pi can
  # use whichever backend is running. The dynamic discovery script below
  # probes all endpoints and merges live model lists.
  #
  # llama-server (port 8001): Qwen3.6-35B-A3B with MTP — 81 t/s
  # llama-server-qwen38 (port 8002): Qwen3.8-27B (dense) — separate unit
  # ollama (port 11434): whatever models you've pulled — use for experiments
  localModelsFile = pkgs.writeText "pi-local-models.json" (
    builtins.toJSON {
      providers.llama-server = {
        baseUrl = "http://localhost:8001/v1";
        api = "openai-completions";
        apiKey = "llama-server";
        models = [
          {
            id = "Qwen3.6-35B-A3B";
            reasoning = true;
            contextWindow = 262144;
            maxTokens = 262144;
          }
        ];
      };
      providers.llama-server-qwen38 = {
        baseUrl = "http://localhost:8002/v1";
        api = "openai-completions";
        apiKey = "llama-server";
        models = [
          {
            id = "Qwen3.8-27B";
            reasoning = true;
            contextWindow = 262144;
            maxTokens = 262144;
          }
        ];
      };
      providers.ollama = {
        baseUrl = "http://localhost:11434/v1";
        api = "openai-completions";
        apiKey = "ollama";
        models = [
          { id = "gemma4:31b"; }
        ];
      };
    }
  );

  cloudModelsFile = pkgs.writeText "pi-cloud-models.json" (
    builtins.toJSON {
      providers.ollama = {
        baseUrl = "https://ollama.com/v1";
        api = "openai-completions";
        # No apiKey here: pi resolves the key from pi2's auth.json.
        models = [
          {
            id = "deepseek-v4-flash";
            reasoning = true;
          }
          {
            id = "deepseek-v4-pro";
            reasoning = true;
          }
          {
            id = "gemma4:31b";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "glm-5.1";
            reasoning = true;
          }
          {
            id = "glm-5.2";
            reasoning = true;
          }
          {
            id = "gpt-oss:20b";
            reasoning = true;
          }
          {
            id = "gpt-oss:120b";
            reasoning = true;
          }
          {
            id = "kimi-k2.5";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "kimi-k2.6";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "kimi-k2.7-code";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "kimi-k3";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "minimax-m2.5";
            reasoning = true;
          }
          {
            id = "minimax-m2.7";
            reasoning = true;
          }
          {
            id = "minimax-m3";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "mistral-large-3:675b";
            input = [
              "text"
              "image"
            ];
          }
          {
            id = "nemotron-3-nano:30b";
            reasoning = true;
          }
          {
            id = "nemotron-3-super";
            reasoning = true;
          }
          {
            id = "nemotron-3-ultra";
            reasoning = true;
          }
          {
            id = "qwen3.5:397b";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
          }
        ];
      };
    }
  );

  # ---- Jail permission set shared by both instances ----
  # General-purpose development baseline. add-pkg-deps exposes each package's
  # binaries and runtime closure, but does not expose privileged host sockets
  # (notably Docker or an SSH agent). Nix daemon access is granted separately
  # below so agents can realise project development environments.
  sharedJailPkgs =
    (with pkgs; [
      # Shell, source control, and navigation
      bash
      coreutils
      diffutils
      fd
      findutils
      gawk
      git
      gnugrep
      gnused
      jq
      ripgrep
      vim
      which
      tree

      # Network access and remote Git
      cacert
      curl
      wget
      openssh
      netcat-openbsd

      # Archives, patches, and file inspection
      file
      patch
      gnutar
      gzip
      bzip2
      xz
      zip
      unzip

      # Language runtimes and package managers
      nodejs
      bun
      pnpm
      yarn
      python313
      uv

      # Native compilation and build systems
      gcc
      gnumake
      cmake
      ninja
      meson
      pkg-config
      clang
      clang-tools
      lld
      lldb
      autoconf
      automake
      libtool
      ccache
      bear
      mold
      patchelf

      # Native diagnostics, static analysis, profiling, and coverage
      valgrind
      linuxPackages.perf
      cppcheck
      lcov

      # Data and diagnostics
      sqlite
      procps
      lsof
      strace
      gdb
      util-linux
      rsync

      # D-Bus and systemd executables for service interaction and inspection
      # inside the jail. These are binaries only (dbus-daemon, dbus-run-session,
      # dbus-monitor, systemctl, busctl, journalctl, udevadm) — they do NOT
      # expose host sockets or grant access to the host's D-Bus/systemd
      # session. The agent can run its own private dbus-run-session but cannot
      # reach the host bus unless explicitly bind-mounted (which we never do).
      dbus
      systemd

      # Nix and repository quality tools. The Nix CLI uses the intentionally
      # exposed daemon socket configured by nixDaemonJailAccess below.
      nix
      nixfmt-rfc-style
      statix
      deadnix
      shellcheck
      shfmt
    ])
    ++ cfg.extraJailPackages;

  # Let jailed agents evaluate, build, and run project-provided Nix shells and
  # flake apps. The daemon performs store writes while the jail sees the whole
  # store read-only, including paths realised after the jail starts. Keep agent
  # users out of nix.settings.trusted-users: daemon access by a trusted user is
  # effectively root access and would defeat the jail's security boundary.
  #
  # NIX_CONFIG includes cooperative Nix build scheduling controls (max-jobs
  # and cores). They reduce build parallelism but are not hard process, memory,
  # CPU, or disk limits.
  #
  # Recommended follow-up for process/memory limits (not implemented here
  # because bwrap has no native cgroup controls and requiring systemd-run
  # inside the wrapper would break non-systemd hosts):
  #   Wrap the bwrap invocation in:
  #     systemd-run --user --slice=pi2.slice \
  #       --property=MemoryMax=16G --property=TasksMax=512 \
  #       -- bwrap ...
  #   This requires the host to run systemd and the user session to support
  #   systemd-run --user. Implement only when a systemd-only path is acceptable.
  nixDaemonJailAccess =
    combinators:
    with combinators;
    compose [
      (unsafe-add-raw-args "--dir /nix/var --dir /nix/var/nix")
      (readonly "/nix/store")
      (readonly "/nix/var/nix/daemon-socket")
      (set-env "NIX_REMOTE" "daemon")
      (set-env "NIX_CONFIG" "experimental-features = nix-command flakes\nmax-jobs = 4\ncores = 8")
      (set-env "NIX_PATH" "nixpkgs=${pkgs.path}")
    ];

  # Keep the ALSA-to-PipeWire module declaration self-contained in the jail.
  # Binding the host's /etc/alsa directory is insufficient on NixOS because
  # its entries are activation-managed symlinks whose /etc/static targets are
  # intentionally absent from the jail.
  pipewireAlsaModulesConfig = pkgs.writeText "pi-jail-pipewire-alsa-modules.conf" ''
    pcm_type.pipewire {
      libs.native = ${pkgs.pipewire}/lib/alsa-lib/libasound_module_pcm_pipewire.so ;
    }
    ctl_type.pipewire {
      libs.native = ${pkgs.pipewire}/lib/alsa-lib/libasound_module_ctl_pipewire.so ;
    }
  '';

  # rpiv-voice's decibri native addon records through ALSA. On our desktop
  # hosts, ALSA's default device is the PipeWire plugin, so expose the user's
  # PipeWire socket and mount only the three pinned ALSA configuration files
  # needed by that plugin rather than granting access to /dev/snd or /etc/static.
  # The addon is an upstream prebuilt ELF without a Nix RPATH; LD_LIBRARY_PATH
  # supplies its libasound.so.2 dependency from the pinned nixpkgs closure.
  microphoneJailAccess =
    combinators:
    with combinators;
    compose [
      pipewire
      (unsafe-add-raw-args "--dir /etc/alsa --dir /etc/alsa/conf.d --ro-bind ${pipewireAlsaModulesConfig} /etc/alsa/conf.d/49-pipewire-modules.conf --ro-bind ${pkgs.pipewire}/share/alsa/alsa.conf.d/50-pipewire.conf /etc/alsa/conf.d/50-pipewire.conf --ro-bind ${pkgs.pipewire}/share/alsa/alsa.conf.d/99-pipewire-default.conf /etc/alsa/conf.d/99-pipewire-default.conf")
      (set-env "LD_LIBRARY_PATH" "${lib.getLib pkgs.alsa-lib}/lib")
    ];

  # ---- Instance 1: pi (primary coding agent) ----
  # Same config as before: context-mode + pi-subagents, gemma4:31b,
  # persisted home "pi-coder", vim editor.
  piMain = inputs.pi-nix.lib.mkCodingAgent {
    inherit pkgs;
    modules = [
      {
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
            "${piExtensionDeps}/node_modules/@juicesharp/rpiv-voice/index.ts"
            "${piExtensionDeps}/node_modules/@tintinweb/pi-subagents/src/index.ts"
          ];
          skills = [ "${piExtensionDeps}/node_modules/context-mode/skills" ];

          # Load the Firecrawl credential at runtime so it never enters the Nix
          # store. pi.nix exports file-backed values before starting the agent.
          environment = {
            FIRECRAWL_API_KEY.file = "/etc/nixos/.secrets/firecrawl-api-key";
            FIRECRAWL_API_URL.value = "https://firecrawl.tatchi.org/v1";
          };

          # bubblewrap isolation via jail.nix. The module always binds pi's agent
          # dir (~/.pi/agent) read-write itself, so it is intentionally absent from
          # this list; persist-home keeps the imperative npm install root
          # (~/.local/share/pi/npm) across launches so `pi install` experiments
          # survive relaunches.
          jail.enable = true;
          jail.permissions =
            combinators: with combinators; [
              network
              # The interactive pi TUI needs direct terminal I/O that --new-session
              # (bwrap's default) breaks. no-new-session is the narrowest safe
              # alternative: the jail still has private PID/IPC/mount/user/UTS/cgroup
              # namespaces and /tmp, /dev, /proc, /home are all tmpfs/procced/deved.
              # Only terminal session isolation is relaxed. See jail.nix docs for
              # no-new-session security implications.
              no-new-session
              (persist-home "pi-coder")
              # Allow SSH administration with the user's existing key, config, and
              # known-hosts entries. Read-only preserves the host's credentials;
              # add remote host keys to ~/.ssh/known_hosts before using pi.
              (unsafe-add-raw-args "--ro-bind-try ${config.home.homeDirectory}/.ssh ${config.home.homeDirectory}/.ssh")
              (set-env "EDITOR" "vim")
              (set-env "VISUAL" "vim")
              (add-pkg-deps sharedJailPkgs)
              (microphoneJailAccess combinators)
              (nixDaemonJailAccess combinators)
              # WSL: /etc/resolv.conf is a symlink to /mnt/wsl/resolv.conf. jail.nix
              # recreates the symlink but only bind-mounts targets under /nix/store,
              # so inside the jail the link dangles, glibc falls back to
              # 127.0.0.1:53, and every lookup fails with EAI_AGAIN (this breaks
              # OAuth login, which resolves platform.claude.com). Bind the target so
              # the link resolves. Uses -try because the path is absent on non-WSL
              # hosts, where this becomes a no-op.
              (unsafe-add-raw-args "--ro-bind-try /mnt/wsl/resolv.conf /mnt/wsl/resolv.conf")
              # The environment wrapper runs inside the jail, so expose only the
              # file required by FIRECRAWL_API_KEY.file, read-only.
              (unsafe-add-raw-args "--dir /etc/nixos --dir /etc/nixos/.secrets --ro-bind-try /etc/nixos/.secrets/firecrawl-api-key /etc/nixos/.secrets/firecrawl-api-key")
              (unsafe-add-raw-args "--dir /usr/bin --symlink ${pkgs.coreutils}/bin/env /usr/bin/env")
              # The outer wrapper canonicalizes the Git worktree and derives a
              # readable destination from that validated root's basename.
              (unsafe-add-raw-args ''--dir /workspace --bind "$PI_JAIL_WORKSPACE_SOURCE" "$PI_JAIL_WORKSPACE_DESTINATION"'')
              (unsafe-add-raw-args ''--chdir "$PI_JAIL_WORKSPACE_DESTINATION"'')
            ];

          models = localModelsFile;
          settings = {
            # Ollama is the default (auto-starts at boot, always available).
            # Switch to llama-server manually in pi settings when you want
            # MTP 81 t/s speed (after: sudo systemctl start llama-server).
            defaultProvider = "ollama";
            defaultModel = "gemma4:31b";
          };
        };
      }
    ];
  };

  # Discover live models from both backends on every launch. Probes
  # llama-server (:8001) and Ollama (:11434), merges whatever responds.
  # Keeps the static catalog above as a fallback. Uses Python (always
  # available) instead of jq for the JSON merge.
  piMainDynamic = pkgs.writeShellScriptBin "pi" ''
        ${prepareWorkspace}

        agent_dir="${config.home.homeDirectory}/.pi/agent"
        ${pkgs.coreutils}/bin/mkdir -p "$agent_dir"

        # Start from the static fallback catalog
        ${pkgs.coreutils}/bin/cp ${localModelsFile} "$agent_dir/models.json"
        ${pkgs.coreutils}/bin/chmod 0600 "$agent_dir/models.json"

        # Probe and merge both backends using Python
        ${pkgs.python3}/bin/python3 -c '
    import json, urllib.request, sys

    models_path = sys.argv[1]
    with open(models_path) as f:
        catalog = json.load(f)

    for provider, url, reasoning in [
        ("llama-server", "http://localhost:8001/v1/models", True),
        ("llama-server-qwen38", "http://localhost:8002/v1/models", True),
        ("ollama", "http://localhost:11434/v1/models", False),
    ]:
        try:
            req = urllib.request.Request(url, headers={"Authorization": "Bearer x"})
            resp = urllib.request.urlopen(req, timeout=3)
            data = json.loads(resp.read())
            models = []
            for m in data.get("data", []):
                mid = m.get("id")
                if mid:
                    entry = {"id": mid}
                    if reasoning:
                        entry["reasoning"] = True
                    models.append(entry)
            models.sort(key=lambda x: x["id"])
            if models:
                catalog.setdefault("providers", {})[provider] = catalog.get("providers", {}).get(provider, {})
                merged_models = []
                for m in models:
                    mid = m.get("id")
                    if mid:
                        entry = {"id": mid}
                        if reasoning:
                            entry["reasoning"] = True
                            entry["contextWindow"] = 262144
                            entry["maxTokens"] = 262144
                        merged_models.append(entry)
                merged_models.sort(key=lambda x: x["id"])
                if merged_models:
                    catalog["providers"][provider]["models"] = merged_models
        except Exception:
            pass  # backend not running — keep static fallback

    with open(models_path, "w") as f:
        json.dump(catalog, f)
    ' "$agent_dir/models.json"

        ${pkgs.coreutils}/bin/chmod 0600 "$agent_dir/models.json"
        exec ${piMain.package}/bin/pi "$@"
  '';

  # ---- Instance 2: pi2 (secondary, separately configured) ----
  # Separate persisted home ("pi2"), separate agent dir (~/.pi/agent2), and a
  # per-host provider/model via pimodule.pi2.{provider,model}. Extend/modify
  # this block to diverge further (different extensions, jail packages, rules).
  pi2 = inputs.pi-nix.lib.mkCodingAgent {
    inherit pkgs;
    modules = [
      {
        config.pi.coding-agent = {
          extensions = [
            "${piExtensionDeps}/node_modules/context-mode/build/adapters/pi/extension.js"
            "${piExtensionDeps}/node_modules/@juicesharp/rpiv-voice/index.ts"
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
            FIRECRAWL_API_KEY.file = "/etc/nixos/.secrets/firecrawl-api-key";
            FIRECRAWL_API_URL.value = "https://firecrawl.tatchi.org/v1";
          };

          jail.enable = true;
          # ---- Credential boundary ----
          # File-backed secrets (FIRECRAWL_API_KEY.file) avoid Nix-store leakage
          # but are still readable by the jailed agent at runtime. The jail has
          # network access, so the agent can exfiltrate any readable secret.
          # Prefer capability/proxy-based access in the future (e.g. a local
          # HTTP proxy that injects credentials per-request) rather than
          # exposing raw credential files.
          jail.permissions =
            combinators:
            with combinators;
            [
              network
              # Preserve the controlling terminal session so pi2's interactive
              # TUI receives terminal resize events. This deliberately omits
              # bwrap's --new-session protection against terminal-session ioctls
              # such as TIOCSTI; all other jail namespaces remain private.
              no-new-session
              (persist-home "pi2")
              (set-env "EDITOR" "vim")
              (set-env "VISUAL" "vim")
              (add-pkg-deps sharedJailPkgs)
              (microphoneJailAccess combinators)
              (nixDaemonJailAccess combinators)
              # WSL: /etc/resolv.conf is a symlink to /mnt/wsl/resolv.conf. jail.nix
              # recreates the symlink but only bind-mounts targets under /nix/store,
              # so inside the jail the link dangles, glibc falls back to
              # 127.0.0.1:53, and every lookup fails with EAI_AGAIN (this breaks
              # OAuth login, which resolves platform.claude.com). Bind the target so
              # the link resolves. Uses -try because the path is absent on non-WSL
              # hosts, where this becomes a no-op.
              (unsafe-add-raw-args "--ro-bind-try /mnt/wsl/resolv.conf /mnt/wsl/resolv.conf")
              # Firecrawl credential (file-backed, read-only — see credential
              # boundary note above)
              (unsafe-add-raw-args "--dir /etc/nixos --dir /etc/nixos/.secrets --ro-bind-try /etc/nixos/.secrets/firecrawl-api-key /etc/nixos/.secrets/firecrawl-api-key")
              (unsafe-add-raw-args "--dir /usr/bin --symlink ${pkgs.coreutils}/bin/env /usr/bin/env")
              # See the primary wrapper: both instances use the same fail-closed,
              # canonical Git-worktree policy and basename-derived destination.
              (unsafe-add-raw-args ''--dir /workspace --bind "$PI_JAIL_WORKSPACE_SOURCE" "$PI_JAIL_WORKSPACE_DESTINATION"'')
              (unsafe-add-raw-args ''--chdir "$PI_JAIL_WORKSPACE_DESTINATION"'')
            ]
            # Optional, dedicated runner credentials only. A mandatory read-only
            # bind is used so Bubblewrap also fails closed if the directory vanishes
            # between outer-wrapper validation and jail setup. Never expose the
            # workstation's normal ~/.ssh or SSH_AUTH_SOCK.
            ++ lib.optional cfg.pi2.sshRunner.enable (
              unsafe-add-raw-args "--ro-bind ${escapeShellArg sshRunnerSource} ${escapeShellArg "${config.home.homeDirectory}/.ssh"}"
            );

          models = cloudModelsFile;
          # Provider/model come from pimodule.pi2.{provider,model} so each host
          # can point this instance at whatever it has credentials for.
          settings = {
            defaultProvider = cfg.pi2.provider;
            defaultModel = cfg.pi2.model;
          };
        };
      }
    ];
  };

  # mkCodingAgent always produces a binary named "pi". Rename the second
  # instance so both are available side by side on PATH. pi-nix preserves an
  # existing regular models.json, so install the declarative cloud catalog
  # here on every launch; this also replaces pi2's previously copied local
  # Ollama catalog while leaving auth.json untouched.
  pi2Renamed = pkgs.writeShellScriptBin "pi2" ''
    ${prepareWorkspace}
    ${optionalString cfg.pi2.sshRunner.enable ''
      if [ ! -d ${escapeShellArg sshRunnerSource} ] || [ -L ${escapeShellArg sshRunnerSource} ]; then
        printf 'pi2: SSH runner is enabled, but the dedicated directory is missing or is a symlink: %s\n' \
          ${escapeShellArg sshRunnerSource} >&2
        exit 1
      fi
    ''}

    ${pkgs.coreutils}/bin/mkdir -p "${config.home.homeDirectory}/.pi/agent2"
    ${pkgs.coreutils}/bin/install -m 0600 ${cloudModelsFile} "${config.home.homeDirectory}/.pi/agent2/models.json"
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

    # Extension point used by other Home Manager modules (for example Ralph)
    # to expose tools in both curated jail environments without broad host PATH
    # access.
    extraJailPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      internal = true;
      description = "Additional packages exposed inside both Pi jails.";
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
        default = "gpt-5.6-sol";
        example = "claude-opus-5";
        description = ''
          Model id written to pi2's settings as defaultModel. Must be a model
          the chosen provider serves.
        '';
      };

      sshRunner = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Bind-mount only ~/.config/pi2-ssh-runner read-only into the pi2
            jail at ~/.ssh. Enabling this fails closed if that directory is
            absent or is a symlink. The jailed agent can read and copy every
            credential exposed there; security therefore also requires a
            dedicated key, pinned known_hosts, strict client configuration,
            and a restricted server-side account with a forced command.
          '';
        };
      };
    };
  };

  config = mkIf cfg.enable {
    home.packages =
      optional cfg.pi.enable piMainDynamic # → `pi` command  (primary, dynamic local Ollama catalog, ~/.pi/agent)
      ++ optional cfg.pi2.enable pi2Renamed; # → `pi2` command  (secondary, per-host provider, ~/.pi/agent2)

    # Keep the runner's reviewed launcher usable inside the jail. Home Manager
    # updates this one symlink whenever the pinned OpenSSH package changes and
    # the active generation keeps its Nix store target rooted. Other files in
    # the external runner directory remain unmanaged and outside Git.
    home.file.".config/pi2-ssh-runner/factory-ssh" = mkIf (cfg.pi2.enable && cfg.pi2.sshRunner.enable) {
      source = "${pkgs.openssh}/bin/ssh";
      force = true;
    };
  };
}
