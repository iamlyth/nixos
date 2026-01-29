#containers/photoOS.nix
{ modulesPath, config, lib, pkgs, ... }:
let
	ftpDir = "/var/ftp";
	printerDir = "/var/ftp/printer";
in
{
	imports = [
		../modules/paper.nix
		../modules/ssh.nix
		(modulesPath + "/virtualisation/proxmox-lxc.nix")
	];
### BEING HARDWARE CONF IMPORT

  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/pve-vm--106--disk--0";
      fsType = "ext4";
    };

  fileSystems."/mnt/familyvault" =
    { device = "//192.168.5.114/familyvault";
      fsType = "cifs";
    };

  swapDevices = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

### END HARDWARE CONF IMPORT
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
			openssl
		];
		networking.firewall.allowedTCPPorts = [
			28981	#paperless
			21		#ftp
		];
		networking.firewall.allowedTCPPortRanges = [
  		{ from = 51000; to = 51999; }
		];
		papermodule = {
			enable = true;
		};
		sshmodule = {
			enable = true;
			port = [55];
		};

		services.vsftpd = {
			enable = true;
			writeEnable = true;
			localUsers = true;
			chrootlocalUser = true;
			allowWriteableChroot = true;
			forceLocalLoginsSSL = true;
			forceLocalDataSSL = true;
			rsaCertFile = "/var/vsftpd/vsftpd.pem";
			extraConfig = ''
				pasv_enable=YES
				pasv_min_port=51000
				pasv_max_port=51999
				require_ssl_reuse=NO
				ssl_ciphers=HIGH
				seccomp_sandbox=NO
				chmod_enable=YES
				strict_ssl_read_eof=NO
  		'';
		};
	
		services.cron = {
			enable = true;
			systemCronJobs = [
				"*/5 * * * * root ${pkgs.coreutils}/bin/chmod 775 /Users/printer/inbox/*.pdf; ${pkgs.coreutils}/bin/mv /Users/printer/inbox/*.pdf /var/lib/paperless/consume 2>&1 | logger -t paperless-move"
			];
		};

		users.users.printer = {
			isNormalUser = true;                # Create a normal user
			home = "/Users/printer";            # Home directory for FTP uploads
			shell = pkgs.bash;                  # Default shell
			extraGroups = ["vault"];
		};
		
		system.activationScripts.createFtpDirectory = ''
			chown -R printer:vault /Users/printer
			chmod -R 777 /Users/printer
		'';

		time.timeZone = "US/Michigan";

		nix.settings.trusted-users = ["lalobied"];
    users.users.lalobied = {
        isNormalUser = true;
				home = "/Users/lalobied";
				extraGroups = ["wheel"];
    };

		system.stateVersion = "25.11";
}
