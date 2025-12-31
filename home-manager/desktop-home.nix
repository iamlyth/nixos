{config, pkgs, ...}:
{
  imports = [
		./modules/zsh.nix
		./modules/vim.nix
		./modules/gnome.nix
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
