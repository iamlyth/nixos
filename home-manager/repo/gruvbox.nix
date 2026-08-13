{
  config,
  pkgs,
  lib,
  ...
}:
with lib;
let
  cfg = config.gruvboxmodule;
  # nixpkgs removed gruvbox-gtk-theme after its GTK 2 murrine engine became
  # unmaintained. Build the actively used GTK 3/4 theme directly and omit the
  # GTK 2 runtime dependency; this preserves the Gruvbox desktop theme without
  # reintroducing gtk-engine-murrine.
  gruvbox-gtk = pkgs.stdenvNoCC.mkDerivation {
    pname = "gruvbox-gtk-theme";
    version = "0-unstable-2025-10-23";
    src = pkgs.fetchFromGitHub {
      owner = "Fausto-Korpsvart";
      repo = "Gruvbox-GTK-Theme";
      rev = "578cd220b5ff6e86b078a6111d26bb20ec8c733f";
      hash = "sha256-RXoPj/aj9OCTIi8xWatG0QpDAUh102nFOipdSIiqt7o=";
    };
    nativeBuildInputs = [ pkgs.sassc ];
    buildInputs = [ pkgs.gnome-themes-extra ];
    dontBuild = true;
    postPatch = ''
      patchShebangs themes/install.sh
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/themes"
      cd themes
      ./install.sh -n Gruvbox -d "$out/share/themes"
      runHook postInstall
    '';
    meta = {
      description = "GTK theme based on the Gruvbox colour palette";
      homepage = "https://github.com/Fausto-Korpsvart/Gruvbox-GTK-Theme";
      license = lib.licenses.gpl3Plus;
      platforms = lib.platforms.unix;
    };
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
      gruvbox-gtk
      gruvbox-plus-icons
    ];

    gtk = {
      enable = true;
      theme = {
        name = "Gruvbox-Light";
        package = gruvbox-gtk;
      };
      iconTheme = {
        name = "Gruvbox-Plus-Dark";
        package = gruvbox-plus-icons;
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
        @import url("${gruvbox-gtk}/share/themes/Gruvbox-Light/gtk-4.0/gtk.css");

        @media (prefers-color-scheme: dark) {
          @import url("${gruvbox-gtk}/share/themes/Gruvbox-Dark/gtk-4.0/gtk.css");
        }
      '';
    };
    xdg.configFile."gtk-4.0/gtk-dark.css" = lib.mkForce {
      source = "${gruvbox-gtk}/share/themes/Gruvbox-Dark/gtk-4.0/gtk-dark.css";
    };
    xdg.configFile."gtk-4.0/assets" = lib.mkForce {
      source = "${gruvbox-gtk}/share/themes/Gruvbox-Dark/gtk-4.0/assets";
    };
    xdg.configFile."gtk-4.0/settings.ini" = lib.mkForce {
      text = ''
        [Settings]
      '';
    };
  };
}
