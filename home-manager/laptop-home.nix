{config, pkgs, ...}:
{
  imports = [
		./repo/zsh.nix
		./repo/nvim.nix
		./repo/gnome.nix
  ];
	nvimmodule = {
		enable = true;
	};
	zshmodule = {
		enable = true;
		lite = false;
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

		iconTheme = {
			name = "Gruvbox-Light";
			package = pkgs.gruvbox-gtk-theme;
		};

	};
	home.sessionVariables.GTK_THEME = "Gruvbox-Light";

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
	};
  home.stateVersion = "25.11";
}
