{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ../modules/default.nix
    ];

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
  # packages = with pkgs; [       tree ];
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).

  # Enable the Flakes feature and the accompanying new nix command-line tool
  nix.settings.experimental-features = ["nix-command" "flakes"];
  environment.systemPackages = with pkgs; [
    # Flakes clones its dependencies through the git command so
    # git must be installed first
    git
    curl
    zip
    unzip
    wget
    screen
    nmap
  ];

  # List services that you want to enable:
  nixpkgs.config.allowUnfree = true; # Plex is unfree

  ### ZSH FIX THIS
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  ### PLEX
  plexmodule = {
    enable = true;
  };

  ### RADARR
  radarrmodule = {
    enable = true;
  };

  ### SSH
  sshmodule = {
    enable = true;
    port = [55];
  };

  system.stateVersion = "25.05";
}

