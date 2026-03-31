{config, pkgs, lib, ...}:
{
  imports = [
		./repo/zsh.nix
		./repo/nvim.nix
		./repo/gnome.nix
		./repo/lutris.nix
		./repo/gruvbox.nix
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

	gruvboxmodule = {
		enable = true;
	};

  home.stateVersion = "25.05";
}
