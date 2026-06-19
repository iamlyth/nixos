{ config, lib, pkgs, ... }:
{
  imports = [
    ../modules/ssh.nix
  ];

  # Kernel, firmware, DTB, bootloader, U-Boot, audio support kernel
  # modules etc. all come from nixos-raspberrypi's raspberry-pi-4.base
  # module wired in at the flake level. Anything we declare here is
  # just host-level config on top.

  # SD-card layout produced by nixos-raspberrypi's sd-image module.
  # mkDefault so the sd-image's own definitions (which set the same
  # device/fsType plus extra options like x-systemd.automount on
  # /boot/firmware) win during image generation, and ours take over
  # at runtime rebuild when sd-image isn't imported.
  fileSystems."/" = lib.mkDefault {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  fileSystems."/boot/firmware" = lib.mkDefault {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
  };

  # profiles/base.nix (inherited via sd-image) flips ZFS on in
  # boot.supportedFilesystems, which then fails an assertion because
  # the rpi kernel's bundled ZFS version doesn't match 26.05's zfs
  # userspace tooling. We don't mount any ZFS volumes on the Pi
  # anyway.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # 4 GB swap file so heavyweight nixos-rebuilds (PipeWire / ffmpeg /
  # kernel modules) don't OOM. SD-card I/O makes this slow, but it
  # keeps native aarch64 builds working — which avoids the
  # qemu-binfmt TCG icount bug we'd otherwise hit cross-building from
  # x86_64.
  swapDevices = [{
    device = "/var/swap";
    size = 4096;
  }];

  networking.hostName = lib.mkDefault "pitemplate";
  networking.useDHCP = lib.mkDefault true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  sshmodule = {
    enable = true;
    port = [ 22 ];
  };

  # Advertise this host over mDNS so it's reachable as
  # `<hostName>.local` on the LAN, regardless of whether the router
  # exposes the IP/AAAA assignments in its UI.
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };

  users.users.lalobied = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    password = "nixos";
  };

  environment.systemPackages = with pkgs; [
    git
    vim
  ];

  time.timeZone = "US/Michigan";

  system.stateVersion = "26.05";
}
