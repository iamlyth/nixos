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
    # markitdown pulls in a heavy python closure (openai, fastapi, ...) whose
    # inline-snapshot test dep fails to build on the current nixpkgs-unstable.
    # Off for now; markitdown will move to an on-demand uv environment instead.
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
  home.stateVersion = "25.11";
}
