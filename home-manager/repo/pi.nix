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
in
{
  # pi is configured through pi-nix's own home-manager module
  # (programs.pi.coding-agent) instead of a hand-rolled mkCodingAgent + jail
  # wrapper. The module bundles the jail (same jail.nix rev we pinned before),
  # the settings/models management, and the --extension/--skill plumbing.
  imports = [ inputs.pi-nix.homeManagerModules.coding-agent ];

  options.pimodule.enable =
    mkEnableOption "pi coding agent (via the pi-nix home-manager module)";

  config = mkIf cfg.enable {
    programs.pi.coding-agent = {
      enable = true;

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
        (persist-home "pi-coder")
        (set-env "EDITOR" "vim")
        (set-env "VISUAL" "vim")
        (add-pkg-deps (with pkgs; [
          git fd bash gnused findutils coreutils gnugrep ripgrep gawk
          diffutils jq nodejs python313 gcc gnumake sqlite pkg-config bun vim
        ]))
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
  };
}
