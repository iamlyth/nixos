{ pkgs, lib, config, ... }:
with lib;
let
  cfg = config.zshmodule;
  pure = import ../../config/zsh.nix { inherit (cfg) lite; };
in {
  options.zshmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the zsh service.
      '';
    };

    lite = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable compatibility mode.
      '';
    };
  };
  config = mkIf cfg.enable {
    programs.direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv.enable = true;
    };
    programs.zsh = {
      enable = true;
      inherit (pure) autocd enableCompletion;
      autosuggestion.enable = pure.autosuggestion;
      syntaxHighlighting.enable = pure.syntaxHighlighting;
      history = pure.history;
      oh-my-zsh = {
        enable = true;
        inherit (pure.ohMyZsh) theme plugins;
      };
      shellAliases = pure.shellAliases;
      sessionVariables = {
        EDITOR = "vim";
      };
    };
  };
}
