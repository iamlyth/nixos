 { config, pkgs, lib, ...}:
{
  imports = [
    ./repo/zsh.nix
    ./repo/nvim.nix
    ./repo/gnome.nix
    ./repo/lutris.nix
    ./repo/gruvbox.nix
    ./repo/pi.nix
    ./repo/python.nix
    ./repo/rust.nix
    ./repo/ghostty.nix
    ./repo/tmux.nix
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
  pimodule = {
    enable = true;
  };
  pythonmodule = {
    enable = true;
  };
  rustmodule = {
    enable = true;
  };
  ghosttymodule = {
    enable = true;
  };
  tmuxmodule = {
    enable = true;
  };
  home.stateVersion = "25.11";
}
