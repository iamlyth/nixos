{...}:
{
  home.stateVersion = "25.11";
  imports = [
    ./repo/zsh.nix
    ./repo/nvim.nix
		./repo/claude.nix
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
}
