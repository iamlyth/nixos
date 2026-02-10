{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../modules/default.nix
    ];

  #nixpkgs.config.allowUnfree = true;

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
  ];

  ### SSH
  sshmodule = {
    enable = true;
    port = [55];
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  #bootloader
  # boot.loader.grub.enable = true;
  # boot.loader.grub.device = "/dev/sda";
  # boot.loader.grub.useOSProber = true;

  networking.hostName = "dOS";
  networking.networkmanager.enable = true;

  #enable X11
  services.xserver.enable = true;

  #enable GNOME
  services.xserver.displayManager.gdm.enable = true;
  services.xserver.desktopManager.gnome.enable = true;

  #keymap in X11
  services.xserver.xkb = {
	layout = "us";
	variant = "";
  };

  #enable sound
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
	enable = true;
	alsa.enable = true;
	alsa.supportt32bit = true;
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
