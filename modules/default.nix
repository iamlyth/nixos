{pkgs, lib, config, ...}:

{
  imports = [
    ./ssh.nix
		./desktop.nix
		./immich.nix
		./media.nix
		./paper.nix	
  ];
}
