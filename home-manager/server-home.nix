{...}:
{
  imports = [
    ./repo/zsh.nix
    ./repo/vim.nix
    ./repo/tmux.nix
  ];

  zshmodule = {
    enable = true;
    lite = true;
  };

  vimmodule = {
    enable = true;
  };

  tmuxmodule = {
    enable = true;
  };

}
