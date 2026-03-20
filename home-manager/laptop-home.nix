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
  home.stateVersion = "25.11";
}
