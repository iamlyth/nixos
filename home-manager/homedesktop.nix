{config, pkgs, ...}:
{
  imports = [
    ./zsh.nix
    ./vim.nix
	./gnome.nix
  ];

  #home.file.".config/Mumble/Mumble/mumble_settings.json" = {
  #  text = builtins.readFile ../config/mumble_settings.json;
  #  executable = false;
  #};
  home.stateVersion = "25.05";
}
