{ config, lib, pkgs, stablenix, modulesPath, ... }:
{
  imports =
    [
	  	../modules/desktop.nix
(modulesPath + "/installer/scan/not-detected.nix")
    ];

	### HARDWARE CONFIG STARTS HERE

boot.initrd.availableKernelModules = [ "xhci_pci" "nvme"];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/mapper/luks-37c6e84c-b4f6-4b9a-905a-26035ae731b2";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-37c6e84c-b4f6-4b9a-905a-26035ae731b2".device = "/dev/disk/by-uuid/37c6e84c-b4f6-4b9a-905a-26035ae731b2";
	boot.initrd.luks.devices."luks-3a743a5b-b266-4110-8476-2beb38ce31c9".device = "/dev/disk/by-uuid/3a743a5b-b266-4110-8476-2beb38ce31c9";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/6BDA-A389";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/mapper/luks-3a743a5b-b266-4110-8476-2beb38ce31c9"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;


	### HARDWARE CONFIG ENDS HERE

  nixpkgs.config.allowUnfree = true; #allow proprietary packages

  ###SHELL
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  ###OS TOOLS
  nix.settings.experimental-features = ["nix-command" "flakes"];
  environment.systemPackages = with pkgs; 
	[
    git
    curl
    zip
    unzip
    wget
    nmap
		sbctl 					#for making secure boot keys
		nfs-utils 			#for mounting NFS drives
		cifs-utils
		eza							#ls replacement
		fzf							#needed for zsh auto suggestion

    #desktop applications
    librewolf
    evolution
    gparted
		darktable				#photo editing	
	  filezilla
    mangohud        #not using this at the moment
		gnome-tweaks		#for fixing my fonts
		dnsutils				#DNS diagnosing
		
		#framework 12 specific
		sbctl						#for debugging and troubleshooting secureboot
		tpm2-tss				#for using the tpm2 chip with systemd-cryptenroll
  ];

  ### DESKTOP OPTIONS
  desktop = {
    enable = true;
		vpn.enable = true;
		nvidia.enable = false;
		intel.enable = true;
  };

	services.avahi = {
		enable = true;
		nssmdns4 = true;
		openFirewall = true;
	};

	services.printing = {
		enable = true;
		drivers = with pkgs; [
			cups-filters
			cups-browsed
		];
	};

  ## Flatpak
  services.flatpak.enable = true;

  ## fwupd Firmware updater
	services.fwupd.enable = true;

	# Bootloader.
	boot.loader.systemd-boot.enable = lib.mkForce false;
	boot.initrd.systemd.enable = true;
	boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
	#boot.loader.systemd-boot.enable = true;
	#boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    networkmanager.enable = true;
    firewall = rec {
      allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
    hostName = "laptop"; # Define your hostname.
    nameservers = ["192.168.5.111"];
    interfaces.wlp0s20f3.ipv4.addresses = [{
      address = "192.168.4.24";
      prefixLength = 16;
    }];
    defaultGateway = {
      address = "192.168.4.1";
	    interface = "wlp0s20f3";
	  };
  };

  #fileSystems."/home/lalobied/Cloud" = {
  #  device = "//192.168.5.114/Personal-Drive";
	#	fsType = "cifs";
	#	options = [
	#		"credentials=/etc/nixos/.secrets/smbcred"
	#		"x-systemd.automount"
	#		"noauto"
	#		"x-systemd.idle-timeout=600"
	#		"x-systemd.mount-timeout=15"
	#		"uid=1000"
	#		"gid=100"
	#		"rw"
	#		"file_mode=0757"
	#		"dir_mode=0757"
 	#		"x-systemd.requires=network-online.target"
	#		"x-systemd.after=network-online.target" 
	#		"_netdev"
	#	];
	#};

  #enable sound
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
		enable = true;
		alsa.enable = true;
		alsa.support32Bit = true;
		pulse.enable = true;
  };

  # Set your time zone.
  time.timeZone = "US/Michigan";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lalobied = {
    isNormalUser = true;
    home = "/home/lalobied";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  };

  system.stateVersion = "25.11";
}
