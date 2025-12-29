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
  #home.file.".config/Mumble/Mumble/mumble_settings.json" = {
  #  text = builtins.readFile ../config/mumble_settings.json;
  #  executable = false;
  #};
  home.stateVersion = "25.05";
}
