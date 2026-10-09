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
  pimodule = {
    enable = true;
    pi.enable = false; # local ollama (gemma4:31b)
    pi2 = {
      enable = true;
      provider = "openai-codex";
      model = "gpt-6-sol";
      sshRunner.enable = false;
    };
  };

  home.stateVersion = "26.05";
}
