{ lib, config, pkgs, inputs, ... }:
with lib;
let
  cfg = config.pimodule;
  jail = inputs.jaildotnix.lib.init pkgs;
  piPackage = inputs.pi-nix.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;

  piAgentDir = "${config.home.homeDirectory}/.pi/agent";

  # Pi extensions, nix-pinned instead of `pi install npm:...` (which leaves
  # imperative, self-updating state in ~/.pi/agent). To update:
  # scripts/update-deps.sh context-mode "@tintinweb/pi-subagents"
  #
  # Built with pi.nix's own nixpkgs, not ours: context-mode ships the
  # native better-sqlite3 addon, which must match the node ABI that pi
  # itself is wrapped with.
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
    # Fetcher v1 skips lock entries flagged "peer": true (the pi packages
    # that pi-subagents peer-depends on), which npm ci then can not find
    # offline. v2 fetches them.
    npmDepsFetcherVersion = 2;
    nativeBuildInputs = [ piPkgs.python3 ];
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r node_modules $out/
    '';
  };

  # Wrapper that passes the pinned extensions (and context-mode's skills)
  # to pi via --extension/--skill flags on every launch. The entry points
  # come from each package's "pi" field in package.json, the same ones
  # `pi install` would register.
  piWrapped = (inputs.pi-nix.lib.mkCodingAgent {
    inherit pkgs;
    modules = [{
      pi.coding-agent = {
        package = piPackage;
        extensions = [
          "${piExtensionDeps}/node_modules/context-mode/build/adapters/pi/extension.js"
          "${piExtensionDeps}/node_modules/@tintinweb/pi-subagents/src/index.ts"
        ];
        skills = [ "${piExtensionDeps}/node_modules/context-mode/skills" ];
      };
    }];
  }).package;

  modelsJson = builtins.toJSON {
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
  };

  jailed-pi = jail "pi" piWrapped [
    jail.combinators.network
    (jail.combinators.persist-home "pi-coder")
    (jail.combinators.try-readwrite piAgentDir)
    (jail.combinators.set-env "PI_AGENT_DIR" piAgentDir)
    (jail.combinators.set-env "EDITOR" "vim")
    (jail.combinators.set-env "VISUAL" "vim")
    (jail.combinators.add-pkg-deps (with pkgs; [ git fd bash gnused findutils coreutils gnugrep ripgrep gawk diffutils jq nodejs python313 gcc gnumake sqlite pkg-config bun vim ]))
    (jail.combinators.unsafe-add-raw-args "--dir /usr/bin --symlink ${pkgs.coreutils}/bin/env /usr/bin/env")
    (jail.combinators.unsafe-add-raw-args ''--bind "$PWD" "/workspace/$(basename "$PWD")"'')
    (jail.combinators.unsafe-add-raw-args ''--chdir "/workspace/$(basename "$PWD")"'')
  ];
in
{
  options.pimodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable pi coding agent
      '';
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ jailed-pi ];

    home.activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${piAgentDir}"

      echo '${modelsJson}' > "${piAgentDir}/models.json"

      settingsFile="${piAgentDir}/settings.json"
      if [ ! -f "$settingsFile" ]; then
        echo '{}' > "$settingsFile"
      fi
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq '. + {defaultProvider: "ollama", defaultModel: "gemma4:31b"}' "$settingsFile" > "$tmp"
      run mv "$tmp" "$settingsFile"
    '';
  };
}
