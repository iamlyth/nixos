{ config, lib, pkgs, modulesPath, ... }:

{
  imports =
    [
      ../modules/default.nix
      (modulesPath + "/profiles/qemu-guest.nix")
    ];

  #IMPORT OF hardware-configuration.nix
    boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci"
"virtio_scsi" "sd_mod" "sr_mod"];
    boot.initrd.kernelModules = ["nfs" ];
		boot.initrd.supportedFilesystems =["nfs"];
    #boot.kernelModules = [ ];
    #boot.extraModulePackages = [ ];

    fileSystems."/" =
      { device = "/dev/disk/by-uuid/c78b2723-849c-4fe8-9feb-a06f1ca30666";
        fsType = "ext4";
      };

    swapDevices =
      [ { device = "/dev/disk/by-uuid/cfbb275f-19e3-462a-ade4-8bd3d85107a9"; }
      ];

    # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
    # (the default) this is the recommended approach. When using systemd-networkd it's
    # still possible to use this option, but it's recommended to use it in conjunction
    # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
    networking.useDHCP = lib.mkDefault true;
	networking.firewall.allowedTCPPorts = [ 80 443 ];
    # networking.interfaces.ens18.useDHCP = lib.mkDefault true;

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  #END OF IMPORT OF hardware-configuration.nix
  nixpkgs.config.allowUnfree = true; # Plex is unfree

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
    screen
    nmap
		traceroute
		wireguard-tools
		nfs-utils
		pciutils						#making sure pci-e devices are passed through from host
  ];

  ### MEDIA OPTIONS
  media = {
    enable = true;
		vpn.enable = true;
  };
  users.groups.media = { };

  ### SSH
  sshmodule = {
    enable = true;
    port = [55];
  };

  # Use the systemd-boot EFI boot loader.
  #boot.loader.systemd-boot.enable = true;
  #boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  networking = {
    hostName = "mOS"; # Define your hostname.
    nameservers = ["1.1.1.1" "1.0.0.1"];
    interfaces.ens18.ipv4.addresses = [{
      address = "192.168.5.106";
      prefixLength = 16;
    }];
    defaultGateway = {
      address = "192.168.4.1";
	    interface = "ens18";
	  };
  };

  fileSystems."/run/media/media" = {
    device = "192.168.5.114:/var/nfs/shared/media";
		fsType = "nfs";
    options = [
			#"bind"
      "defaults"
      #"user"
      "rw"
      "nofail"
      "exec"
      "relatime"
    ];
  };

  # Set your time zone.
  time.timeZone = "US/Michigan";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lalobied = {
    isNormalUser = true;
    home = "/home/lalobied";
    extraGroups = [ "wheel" "media" ]; # Enable ‘sudo’ for the user.
  };

  system.stateVersion = "25.05";
}
