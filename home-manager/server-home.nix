{...}:
{
  home.stateVersion = "25.11";
  imports = [
    ./modules/zsh.nix
    ./modules/vim.nix
  ];

	zshmodule = {
		enable = true;
		lite = false;
	};
}
