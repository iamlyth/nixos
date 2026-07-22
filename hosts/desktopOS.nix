 { config, lib, pkgs, inputs, system, stablenix, modulesPath, ... }:
{
  nixpkgs.overlays = [
    # CachyOS kernel packages for boot.kernelPackages. Structural rather
    # than temporary: stays as long as this host runs the CachyOS kernel.
    # Overlay added 2026-04-11.
    inputs.nix-cachyos-kernel.overlays.default
    # FIXME: Remove this once ctranslate2 hash mismatch is fixed upstream.
    # Overlay added 2026-07-08.
    # Checked 2026-07-14: fixed on nixpkgs master 2026-07-05 (PR #538805,
    # same hash as below), but the current unstable pin predates it.
    # Droppable after the next flake update.
    (final: prev: {
      ctranslate2 = prev.ctranslate2.overrideAttrs (oldAttrs: {
        src = (oldAttrs.src or { }).override {
          hash = "sha256-cchwv+esysn/0v6RqD5zp306HfzOjjlCxH5usLETXs0=";
        };
      });
    })
    # Temporarily pull ollama-rocm from an older nixpkgs while the
    # current ollama's reasoning_content streaming breaks pi on /v1.
    # Overlay added 2026-06-08.
    # Checked 2026-07-14: still needed. Fix PR ollama/ollama#16758 is
    # approved but unmerged (tracker ollama/ollama#10976 still open);
    # v0.32.0 shipped 2026-07-11 without it. Unpin only once a release
    # containing the fix reaches nixpkgs, then verify by sending a /v1
    # tool request to gemma4: a fixed build returns real content and
    # tool_calls with nothing in reasoning_content.
    (_: _: {
      ollama-rocm = (import inputs.nixpkgs-ollama {
        inherit system;
        config.allowUnfree = true;
      }).ollama-rocm;
    })
  ];

  imports = [
    ../modules/desktop.nix
    ../modules/ssh.nix
    ../modules/ai.nix
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  # HARDWARE CONFIG STARTS HERE

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "thunderbolt" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest;
  boot.kernelModules = [ "kvm-amd" "sg" ];
  boot.extraModulePackages = [ ];
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Remap memory allocation for AI Model training
  #boot.extraModprobeConfig = ''
  #  options ttm pages_limit=14680064
  #'';

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

  # HARDWARE CONFIG ENDS HERE

  nixpkgs.config.allowUnfree = true; #  allow proprietary packages

  # # # SHELL
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # # # AI
  ai = {
    enable = true;
    acceleration = "rocm";
    # 31b is pi's default model (home-manager/repo/pi.nix); preload it so
    # a fresh install always has it. 26b stays for open-webui sessions.
    models = [ "gemma4:26b" "gemma4:31b" ];
    idleTimeout = "5min";
    openwebui.enable = true;
    openwebui.corsOrigin = "https://ai.tatchi.org";
  };

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
    sbctl           #  for making secure boot keys
    nfs-utils       #  for mounting NFS drives
    cifs-utils
    eza              #  ls replacement
    fzf              #  needed for zsh auto suggestion
    tochd            #  compressing PSX/PS2 games to a single file. No duplicate entries.
    rusty-psn        #  updating ps3 games
    traceroute
    fastfetch
    ripgrep

    ## TUI
    gurk-rs
    irssi

    # desktop applications
    librewolf
    vivaldi
    geary
    gparted
    darktable        #  photo editing  
    discord-ptb
    mumble                                     #  game chat
    (mumble.override { pulseSupport = true; }) #  to add audio to mumble
    zed-editor                                 #  for software development
    filezilla
    mangohud         #  not using this at the moment
    protonup-qt      #  for selecting proton version in steam
    gnome-tweaks     #  for fixing my fonts
    dnsutils         #  DNS diagnosing
    makemkv          #  shredding
    gnome-sound-recorder
    
    # develop applications
    libgcc          #  C/Cpp compilers
    bc
    gcc
    love
  ];

  # DESKTOP OPTIONS
  desktop = {
    enable = true;
    vpn.enable = true;
    nvidia.enable = false;
    intel.enable = false;
    rdp.enable = true;
  };

  # SSH
  sshmodule = {
    enable = true;
    port = [55];
  };

  # gaming
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;
  };
  programs.gamemode.enable = true; #  request for os to optimize to gaming

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

  # Bootloader.
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.lanzaboote = {
    enable = true;
    pkiBundle = "/var/lib/sbctl";
  };
  # boot.loader.systemd-boot.enable = true;
  # boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    networkmanager.enable = true;
    firewall = rec {
      allowedTCPPortRanges = [ { from = 1714; to = 1764; } ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
    hostName = "desktop"; #  Define your hostname.
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
    device = "//192.168.5.114/gamestore";
    fsType = "cifs";
    options = [
      "credentials=/etc/nixos/.secrets/smbcred"
      "x-systemd.automount"
      "noauto"
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

  # enable sound
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
  extraGroups = [ "wheel" ]; #  Enable ‘sudo’ for the user.
  };

  # Disable system from sleeping
  systemd.targets.sleep.enable = false;
  systemd.targets.suspend.enable = false;
  systemd.targets.hibernate.enable = false;
  systemd.targets.hybrid-sleep.enable = false;

  system.stateVersion = "25.11";
}
