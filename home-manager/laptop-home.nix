 { config, pkgs, lib, ...}:
{
  imports = [
    ./repo/zsh.nix
    ./repo/nvim.nix
    ./repo/gnome.nix
    ./repo/gruvbox.nix
    ./repo/pi.nix
    ./repo/python.nix
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
  gruvboxmodule = {
    enable = true;
  };
  pythonmodule = {
    enable = true;
  };
  ghosttymodule = {
    enable = true;
  };
  tmuxmodule = {
    enable = true;
  };
  pimodule = {
    enable = true;
    pi.enable = false;   # no local ollama on laptop
    pi2.enable = true;   # API-key-based pi2 only
  };

  home.stateVersion = "25.11";
}
