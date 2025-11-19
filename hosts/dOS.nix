{ config, lib, pkgs, modulesPath, ... }:
{
  imports =
    [
#      ./desktophardware-configuration.nix
      ../modules/default.nix
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  #IMPORT OF hardware-configuration.nix
  boot.initrd.availableKernelModules = [ "xhci_pci" "ehci_pci" "ahci" "usbhid" "sd_mod" ];
  #boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  #boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/fbdde9e5-0437-46f8-b529-4d6fe7a30f39";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/F513-E426";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/00109afc-63fe-465b-8499-e95a77c59dac"; }
    ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp3s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp4s0.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  #END OF IMPORT

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
    spotify         #muzik
    mumble          #game chat
    (mumble.override { pulseSupport = true; }) #to add audio to mumble
    zed-editor      #for software development
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

  fileSystems."/run/media/lalobied/StorageTanks" = {
    #device = "/dev/sda1";
    device = "/dev/disk/by-uuid/9552b4bf-0c2f-4a53-a1de-37e9539cb4c0";
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

  networking.hostName = "dOS";
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
