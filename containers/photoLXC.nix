#containers/photoOS.nix
{ modulesPath, config, lib, pkgs, ... }:
{
	imports = [
		../modules/immich.nix
		../modules/ssh.nix
		(modulesPath + "/virtualisation/proxmox-lxc.nix")
	];
## Begin hardware import


  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/pve-vm--105--disk--0";
      fsType = "ext4";
    };

  fileSystems."/mnt/familyvault" =
    { device = "//192.168.5.114/familyvault";
      fsType = "cifs";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
## End hardware import

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
			eza
		];
		immichmodule = {
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
