{
  config,
  pkgs,
  lib,
  ...
}:
{
  imports = [
    ./repo/zsh.nix
    ./repo/nvim.nix
    ./repo/gnome.nix
    ./repo/lutris.nix
    ./repo/gruvbox.nix
    ./repo/pi.nix
    ./repo/ralph.nix
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
    pi.enable = true; # local ollama (gemma4:31b)
    pi2 = {
      enable = true;
      provider = "openai-codex";
      model = "gpt-5.6-sol";
    };
  };
  ralphmodule.enable = true;
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

  # Apply this through Flatpak itself rather than managing its mutable override
  # file as a read-only Home Manager symlink. RetroDECK otherwise drops the X11
  # socket permission after activation and must be repaired manually.
  home.activation.retrodeckFlatpakOverride = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${lib.getExe pkgs.flatpak} override --user --socket=x11 net.retrodeck.retrodeck
  '';

  home.stateVersion = "25.11";
}
