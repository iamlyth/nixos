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
    ./repo/claude.nix
  ];
  nvimmodule = {
    enable = true;
  };
  zshmodule = {
    enable = true;
    lite = false;
  };
  gruvboxmodule = {
    enable = false;
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
  claudemodule = {
    enable = true;
  };

  home.stateVersion = "26.05";
}
