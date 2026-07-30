 { config, lib, pkgs, stablenix, modulesPath, ... }:
{
  imports =
    [
      ../modules/desktop.nix
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

  # HARDWARE CONFIG STARTS HERE

  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usbhid"];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];
  boot.plymouth = {
    enable = true;
    theme = "rings";
    themePackages = with pkgs; [
      (adi1090x-plymouth-themes.override {
        selected_themes = [ "rings" ];
      })
    ];
  };

  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_level=3"
    "systemd.show_status=auto"
  ];

  fileSystems."/" =
    { device = "/dev/mapper/luks-a9794c59-2143-4ad5-b038-c2dba17706de";
      fsType = "ext4";
    };

  boot.initrd.luks.devices."luks-a9794c59-2143-4ad5-b038-c2dba17706de".device = "/dev/disk/by-uuid/a9794c59-2143-4ad5-b038-c2dba17706de";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/35C6-75D2";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  swapDevices =
    [ { device = "/dev/mapper/luks-29ba7f18-c61e-4139-b43f-a1943e4c3fa6"; }
    ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  # HARDWARE CONFIG ENDS HERE

  nixpkgs.config.allowUnfree = true; #  allow proprietary packages

  # # # SHELL
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # # #OS TOOLS
  nix.settings.experimental-features = ["nix-command" "flakes"];
  nix.settings.trusted-users = [ "root" "lalobied" ];
  environment.systemPackages = with pkgs; 
  [
    git
    curl
    zip
    unzip
    wget
    nmap
    sbctl             #  for making secure boot keys
    nfs-utils       #  for mounting NFS drives
    cifs-utils
    eza              #  ls replacement
    fzf              #  needed for zsh auto suggestion
    ripgrep
    fastfetch

    # desktop applications
    firefox 
    gparted
    gnome-tweaks    #  for fixing my fonts
  ];

  # DESKTOP OPTIONS
  desktop = {
    enable = true;
    vpn.enable = false;
    nvidia.enable = false;
    intel.enable = false;
    rdp.enable = false;
  };

  # for DNS
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

  # Flatpak
  services.flatpak.enable = true;

  # fwupd Firmware updater
  services.fwupd.enable = true;

  # Bootloader
  #boot.loader.systemd-boot.enable = lib.mkForce false;
  #boot.initrd.systemd.enable = true;
  #boot.lanzaboote = {
  #  enable = true;
  #  pkiBundle = "/var/lib/sbctl";
  #};
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    networkmanager.enable = true;
    firewall = rec {
      enable = true;
      allowedTCPPortRanges = [ ];
      allowedUDPPortRanges = allowedTCPPortRanges;
      trustedInterfaces = [ ];
    };
  hostName = "lyth-desktop"; #  Define your hostname.
  };

  # enable sound
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # fix for nix-ld
  programs.nix-ld.enable = true;

  # Set your time zone.
  time.timeZone = "US/Michigan";

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lalobied = {
    isNormalUser = true;
    home = "/home/lalobied";
  extraGroups = [ "networkmanager" "wheel" ]; #  Enable ‘sudo’ for the user.
  };

  system.stateVersion = "26.05";
}
