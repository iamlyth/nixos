{...}:
{
  imports = [
    ./repo/zsh.nix
    ./repo/vim.nix
  ];

  zshmodule = {
    enable = true;
    lite = true;
  };

  vimmodule = {
    enable = true;
  };

}
