{config, pkgs, lib, ...}:
{
  imports = [
		./repo/zsh.nix
		./repo/nvim.nix
		./repo/gnome.nix
		./repo/lutris.nix
  ];
	nvimmodule = {
		enable = true;
	};
	zshmodule = {
		enable = true;
		lite = false;
	};
	lutrismodule = {
		enable = true;
	};

	home.packages = [
    pkgs.gruvbox-gtk-theme
    pkgs.blackbox-terminal
  ];

  gtk = {
    enable = true;
    theme = {
      name = "Gruvbox-Light";
      package = pkgs.gruvbox-gtk-theme;
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
 #home.file.".config/Mumble/Mumble/mumble_settings.json" = {
  #  text = builtins.readFile ../config/mumble_settings.json;
  #  executable = false;
  #};
  home.stateVersion = "25.05";
}
