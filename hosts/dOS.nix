{ config, lib, pkgs, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../modules/default.nix
    ];

  ##USB Wifi Configuration
  boot.extraModulePackages = with config.boot.kernelPackages; [
    rtl8812au
  ];
  boot.initrd.kernelModules = [ "8812au" ];

  nixpkgs.config.allowUnfree = true; #allow proprietary packages
  nixpkgs.config.nvidia.acceptLicense = true; #accept nvidia EULA

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
    pciutils
    usbutils

    #desktop applications
    librewolf
    evolution
    gparted
    discord-ptb
    spotify
    mumble
    (mumble.override { pulseSupport = true; }) #to add audio to mumble
    zed-editor
    mangohud

    #develop applications
    libgcc
    bc
    linuxHeaders
  ];

  ### DESKTOP OPTIONS
  desktop = {
    enable = true;
  };

  ### SSH
  sshmodule = {
    enable = true;
    port = [55];
  };

  ## Gaming
  programs.steam = {
    enable = true;
    protontricks.enable = true;
  };
  programs.gamemode.enable = true; #request for OS to optimize to gaming
  #programs.mangohud.enable = true;
  #programs.mangohud.settings = {
  #  fps_only = 1;
  #  font_size=12;
  #};
  ## Flatpak
  services.flatpak.enable = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  fileSystems."/run/media/lalobied/StorageTanks" = {
    device = "/dev/sda1";
    fsType = "ext4";
    options = [
      "defaults"
      "user"
      "rw"
      "noauto"
      "exec"
      "relatime"
    ];
  };

  networking.hostName = "dOS";
  networking.networkmanager.enable = true;

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

  system.stateVersion = "25.05";
}
