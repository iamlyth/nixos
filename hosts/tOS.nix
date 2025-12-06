{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [
      ./hardware-configuration.nix
      ../modules/desktop.nix
	  ../modules/default.nix
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

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
    pciutils
    usbutils

    #desktop applications
    librewolf
    evolution
    gparted
    discord-ptb
    spotify         #muzik
    mumble          #game chat
    (mumble.override { pulseSupport = true; }) #to add audio to mumble
    zed-editor      #for software development
	  filezilla
    mangohud        #not using this at the moment

    #develop applications
    libgcc          #C/Cpp compilers
    bc
    linuxHeaders    #Don't need this anymore
    godot           #game development
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
    gamescopeSession.enable = true;
    protontricks.enable = true;
  };
  programs.gamemode.enable = true; #request for OS to optimize to gaming

  ## Flatpak
  services.flatpak.enable = true;

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "tOS";
  networking.networkmanager.enable = true;
  networking.firewall = rec {
    allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
    allowedUDPPortRanges = allowedTCPPortRanges;
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

  system.stateVersion = "25.05";
}
