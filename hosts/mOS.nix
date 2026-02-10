{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./mOShardware-configuration.nix
      ../modules/default.nix
    ];

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
  ];

  ### VPN
  #services.mullvad-vpn.enable = true;

  ### MEDIA OPTIONS
  media = {
    enable = true;
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

  #systemd.network.enable = true;

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
    device = "/dev/disk/by-uuid/b65b7775-596b-447e-85de-db2a1c6bbe9e";
    fsType = "ext4";
    options = [
      "defaults"
      "user"
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
