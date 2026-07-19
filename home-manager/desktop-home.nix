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
    extras = false;
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

  ## Override for Flatpak Retrodeck
  xdg.dataFile."flatpak/overrides/net.retrodeck.retrodeck".text = ''
    [Context]
    sockets=wayland;fallback-x11;pulseaudio;x11

    [Environment]
    XDG_DATA_DIRS=/app/share:/usr/share:/usr/share/runtime/share
  '';

  home.stateVersion = "25.11";
}
