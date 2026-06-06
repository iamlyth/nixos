{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.ghosttymodule;
in
{
  options.ghosttymodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to enable Ghostty terminal emulator.";
    };

    darkTheme = mkOption {
      type = types.str;
      default = "Gruvbox Dark";
      description = "Ghostty theme name to use in dark mode.";
    };

    lightTheme = mkOption {
      type = types.str;
      default = "Gruvbox Light";
      description = "Ghostty theme name to use in light mode.";
    };

    font = mkOption {
      type = types.str;
      default = "JetBrainsMono Nerd Font";
      description = "Font to use in Ghostty.";
    };
    fontSize = mkOption {
      type = types.int;
      default = 12;
      description = "Font size.";
    };
    padding = mkOption {
      type = types.int;
      default = 15;
      description = "Window padding (x and y).";
    };
    enableLigatures = mkOption {
      type = types.bool;
      default = true;
      description = "Enable font ligatures.";
    };
    cursorStyle = mkOption {
      type = types.str;
      default = "block";
      description = "Cursor style (block, beam, underline).";
    };
    cursorBlink = mkOption {
      type = types.bool;
      default = true;
      description = "Enable cursor blinking.";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [ 
      pkgs.ghostty 
      pkgs.jetbrains-mono 
    ];

    xdg.configFile."ghostty/config".text = ''
      theme = dark:${cfg.darkTheme},light:${cfg.lightTheme}

      # Font Settings
      font-family = ${cfg.font}
      font-size = ${toString cfg.fontSize}
      ${if cfg.enableLigatures then "font-feature = \"calt\"" else ""}

      # Window Settings
      window-padding-x = ${toString cfg.padding}
      window-padding-y = ${toString cfg.padding}
    '';
  };
}
