{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [
	  	../modules/desktop.nix
			../modules/ssh.nix
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

### HARDWARE CONFIG STARTS HERE
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/a75c9312-aaf8-43d3-a7e7-f292a54e0e87";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/0A74-1EB6";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/612a57b5-a292-4358-bef0-3b93bbe491a1"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  # networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp191s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp192s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;




	### HARDWARE CONFIG ENDS HERE

  nixpkgs.config.allowUnfree = true; #allow proprietary packages

  ###SHELL
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  ###OS TOOLS
  nix.settings.experimental-features = ["nix-command" "flakes"];
  environment.systemPackages = with pkgs; [
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
		tochd						#compressing PSX/PS2 games to a single file. No duplicate entries.

    #desktop applications
    librewolf
    evolution
    gparted
		darktable				#photo editing	
    discord-ptb
    spotify         #muzik
    mumble          #game chat
    (mumble.override { pulseSupport = true; }) #to add audio to mumble
    zed-editor      #for software development
	  filezilla
    mangohud        #not using this at the moment
		protonup-qt #for selecting proton version in steam
		gnome-tweaks		#for fixing my fonts

		#develop applications
    libgcc          #C/Cpp compilers
    bc
    linuxHeaders    #Don't need this anymore
    godot           #game development
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

  ## Gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
		#extraCompatPackages = with pkgs; [
  	#	proton-ge-bin
		#];
  };
  programs.gamemode.enable = true; #request for OS to optimize to gaming

  ## Flatpak
  services.flatpak.enable = true;

  ## fwupd Firmware updater
	services.fwupd.enable = true;

	# Bootloader.
	boot.loader.systemd-boot.enable = lib.mkForce false;
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


  fileSystems."/run/media/gamestore" = {
    device = "192.168.5.114:/var/nfs/shared/gamestore";
		fsType = "nfs";
    options = [
      "defaults"
      "rw"
      "nofail"
      "exec"
      "relatime"
    ];
  };
	
  fileSystems."/home/lalobied/Cloud" = {
    device = "//192.168.5.114/Personal-Drive";
		fsType = "cifs";
		options = [
			"credentials=/etc/nixos/.secrets/smbcred"
			"x-systemd.automount"
			"noauto"
			"x-systemd.idle-timeout=600"
			"x-systemd.mount-timeout=15"
			"uid=1000"
			"gid=100"
			"rw"
			"file_mode=0757"
			"dir_mode=0757"
 			"x-systemd.requires=network-online.target"
			"x-systemd.after=network-online.target" 
			"_netdev"
		];
	};

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

  system.stateVersion = "25.10";
}
