{...}:
{
  home.stateVersion = "25.11";
  imports = [
    ./modules/zsh.nix
    ./modules/vim.nix
    ./modules/nvim.nix
  ];

	zshmodule = {
		enable = true;
		lite = true;
	};

	nvimmodule = {
		enable = true;
	};
}
