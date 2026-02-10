{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
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
  ];

  ### MEDIA OPTIONS

  media = {
    enable = true;
  };

  ### SSH
  sshmodule = {
    enable = true;
    port = [55];
  };

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "mOS"; # Define your hostname.

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
