#containers/photoOS.nix
{ modulesPath, config, lib, pkgs, ... }:
{
	imports = [
		../modules/paper.nix
		../modules/ssh.nix
		(modulesPath + "/virtualisation/proxmox-lxc.nix")
	];
		#PATH=$PATH:/run/current-system/sw/bin/
		#zsh


		boot.isContainer = true;

		systemd.suppressedSystemUnits = [
			"dev-mqueue.mount"
			"sys-kernel-debug.mount"
			"sys-fs-fuse-connections.mount"
		];
   	
		### SHELL
		programs.zsh.enable = true;
		users.defaultUserShell = pkgs.zsh;

		# List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
  	nix.settings.experimental-features = ["nix-command" "flakes"];
		environment.systemPackages = with pkgs;  [
			git
			cifs-utils
		];
		papermodule = {
			enable = true;
		};
		sshmodule = {
			enable = true;
			port = [55];
		};
		
		time.timeZone = "US/Michigan";

		nix.settings.trusted-users = ["lalobied"];
    users.users.lalobied = {
        isNormalUser = true;
				home = "/Users/lalobied";
				extraGroups = ["wheel"];
    };

		system.stateVersion = "25.11";
}
