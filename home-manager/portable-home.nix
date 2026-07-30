{...}:
{
  home.stateVersion = "25.11";
  imports = [
    ./repo/zsh.nix
    ./repo/nvim.nix
    ./repo/claude.nix
    ./repo/tmux.nix
    ./repo/python.nix
    ./repo/pi.nix
  ];

  zshmodule = {
    enable = true;
    lite = false;
  };

  nvimmodule = {
    enable = true;
  };
  
  claudemodule = {
    enable = true;
  };

  pimodule = {
    enable = true;
    pi2 = {
      enable = true;
      provider = "anthropic";
      model = "claude-opus-5";
    };
  };

  tmuxmodule = {
    enable = true;
  };

  pythonmodule = {
    enable = true;
  };
}
