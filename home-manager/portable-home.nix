{...}:
{
  home.stateVersion = "25.11";
  imports = [
    ./repo/zsh.nix
    ./repo/vim.nix
    ./repo/nvim.nix
  ];

	zshmodule = {
		enable = true;
		lite = true;
	};

	nvimmodule = {
		enable = true;
	};
}
