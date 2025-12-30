#containers/photoOS.nix
{ config, lib, pkgs, ... }:
{
	imports = [
		../modules/default.nix

	];
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    environment.systemPackages = with pkgs;  [
			git
			cifs-utils
		];
		immichmodule = {
			enable = true;
		};
		sshmodule = {
			enable = true;
			port = [55];
		};

    users.users.lalobied = {
        isNormalUser = true;
				home = "/Users/lalobied";
				extraGroups = ["wheel"];
    };

		system.stateVersion = "25.11";
}
