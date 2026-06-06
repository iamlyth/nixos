 { config, pkgs, lib, ...}:
with lib; let
  cfg = config.gruvboxmodule;
  gruvbox-gtk = pkgs.gruvbox-gtk-theme.override {
    iconVariants = [ "Dark" "Light" ];
  };

  gruvbox-plus-icons = pkgs.stdenvNoCC.mkDerivation {
    name = "gruvbox-plus-icon-pack";
    version = "6.3.0";
    src = pkgs.fetchFromGitHub {
      owner = "SylEleuth";
      repo = "gruvbox-plus-icon-pack";
      rev = "v6.3.0";
      hash = "sha256-4UJOiDdw5BxtOjLQjCpkQnUwQRs49GZTShpcElWjAU8=";
    };
    installPhase = ''
      mkdir -p $out/share/icons
      cp -r Gruvbox-Plus-Dark $out/share/icons/
      cp -r Gruvbox-Plus-Light $out/share/icons/
    '';
  };
in
{
  options.gruvboxmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to change icons to a gruvbox theme.
      '';
    };
  };
  config = mkIf cfg.enable {
    home.packages = [
      pkgs.gruvbox-gtk-theme
      gruvbox-plus-icons
    ];

    gtk = {
      enable = true;
      theme = {
        name = "Gruvbox-Light";
        package = pkgs.gruvbox-gtk-theme;
      };
      iconTheme = {
        name = "Gruvbox-Plus-Dark";
        package =  gruvbox-plus-icons;
      };
      gtk4.theme = null;
    };

    dconf.settings = {
      "org/gnome/shell/extensions/nightthemeswitcher/color-scheme" = {
        day = "default";
        night = "prefer-dark";
      };
    };
    xdg.configFile."gtk-4.0/gtk.css" = lib.mkForce {
      text = ''
        @import url("${pkgs.gruvbox-gtk-theme}/share/themes/Gruvbox-Light/gtk-4.0/gtk.css");

        @media (prefers-color-scheme: dark) {
          @import url("${pkgs.gruvbox-gtk-theme}/share/themes/Gruvbox-Dark/gtk-4.0/gtk.css");
        }
      '';
    };
    xdg.configFile."gtk-4.0/gtk-dark.css" = lib.mkForce {
      source = "${pkgs.gruvbox-gtk-theme}/share/themes/Gruvbox-Dark/gtk-4.0/gtk-dark.css";
    };
    xdg.configFile."gtk-4.0/assets" = lib.mkForce {
      source = "${pkgs.gruvbox-gtk-theme}/share/themes/Gruvbox-Dark/gtk-4.0/assets";
    };
    xdg.configFile."gtk-4.0/settings.ini" = lib.mkForce {
      text = ''
        [Settings]
      '';
    };
  };
}
