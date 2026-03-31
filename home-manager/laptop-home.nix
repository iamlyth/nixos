{config, pkgs, lib, ...}:
{
  imports = [
		./repo/zsh.nix
		./repo/nvim.nix
		./repo/gnome.nix
		./repo/gruvbox.nix
  ];
	nvimmodule = {
		enable = true;
	};
	zshmodule = {
		enable = true;
		lite = false;
	};
	gruvboxmodule = {
		enable = true;
	};

  home.stateVersion = "25.11";
}
