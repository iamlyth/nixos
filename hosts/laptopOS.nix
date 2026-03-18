{ config, lib, pkgs, stablenix, modulesPath, ... }:
{
  imports =
    [
	  	../modules/desktop.nix
			../modules/ssh.nix
    ];

	### HARDWARE CONFIG STARTS HERE
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

  ];

  ### DESKTOP OPTIONS
  desktop = {
    enable = true;
		vpn.enable = true;
		nvidia.enable = false;
  };

  ### SSH
  sshmodule = {
    enable = true;
    port = [55];
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
	#boot.loader.systemd-boot.enable = lib.mkForce false;
	#boot.lanzaboote = {
  #  enable = true;
  #  pkiBundle = "/var/lib/sbctl";
  #};
	boot.loader.systemd-boot.enable = true;
	boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    networkmanager.enable = true;
    firewall = rec {
      allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
    hostName = "desktop"; # Define your hostname.
    nameservers = ["192.168.5.111"];
    interfaces.enp191s0.ipv4.addresses = [{
      address = "192.168.5.117";
      prefixLength = 16;
    }];
    defaultGateway = {
      address = "192.168.4.1";
	    interface = "enp191s0";
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
