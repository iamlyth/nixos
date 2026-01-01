{config, pkgs, ...}:
{
  imports = [
		./repo/zsh.nix
		./repo/vim.nix 
		./repo/gnome.nix
  ];

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
