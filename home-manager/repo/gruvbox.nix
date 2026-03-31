{config, pkgs, lib, ...}:
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
			pkgs.blackbox-terminal
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
		};

		dconf.settings = {
			"com/raggesilver/BlackBox" = {
				font = "Monospace 11";
				theme-dark = "Gruvbox Dark";
				theme-light = "Gruvbox Light";
				background-color = "#fbf1c7";
				foreground-color = "#3c3836";
				use-system-font = false;
				terminal-padding = 6;
				palette = [
					"#fbf1c7" "#9d0006" "#79740e" "#b57614"
					"#076678" "#8f3f71" "#427b58" "#7c6f64"
					"#928374" "#cc241d" "#98971a" "#d79921"
					"#458588" "#b16286" "#689d6a" "#3c3836"
				];
			};
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
