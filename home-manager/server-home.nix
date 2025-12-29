{...}:
{
  home.stateVersion = "25.11";
  imports = [
    ./repo/zsh.nix
    ./repo/vim.nix
  ];

	zshmodule = {
		enable = true;
		lite = false;
	};
}
