{ lib, config, pkgs, inputs, ... }:
with lib;
let
  cfg = config.pimodule;
  jail = inputs.jaildotnix.lib.init pkgs;
  piPackage = inputs.pi-nix.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;

  piAgentDir = "${config.home.homeDirectory}/.pi/agent";

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

  jailed-pi = jail "pi" piPackage [
    jail.combinators.network
    (jail.combinators.persist-home "pi-coder")
    (jail.combinators.try-readwrite piAgentDir)
    (jail.combinators.set-env "PI_AGENT_DIR" piAgentDir)
    (jail.combinators.add-pkg-deps (with pkgs; [ git fd bash gnused findutils coreutils gnugrep ripgrep gawk diffutils jq nodejs ]))
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
