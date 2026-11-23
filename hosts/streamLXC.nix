# hosts/streamLXC.nix
# Dedicated Plex LXC — isolated in the DMZ VLAN with a read-only NFS library
# mount. Split from mediaOS for security isolation following the Plex data
# breach. Only Plex runs here; radarr/sonarr/sabnzbd stay on mediaOS.
{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/lxctemplate.nix
    ../modules/repo/plex.nix
    ../modules/ghostty-terminfo.nix
  ];

  # Root filesystem (Proxmox LXC CT 127)
  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--127--disk--0";
    fsType = "ext4";
  };

  # Media library — read-only CIFS bind mount from the Proxmox host.
  # The actual mount is managed by Proxmox (pct set 127 -mp0 /mnt/pve/media,mp=/media,ro=1);
  # this fileSystems entry is documentation-only in an unprivileged LXC.
  # NixOS systemd manages /run as tmpfs, which overwrites Proxmox bind mounts
  # under /run/ — using /media avoids that conflict.
  # Host-side: //192.168.10.50/media → bind ro into /media

  # Suppress NFS rpc_pipefs mount — fails in unprivileged LXC (permission denied).
  # The bind mount from Proxmox replaces NFS-in-container entirely.
  systemd.suppressedSystemUnits = [
    "var-lib-nfs-rpc_pipefs.mount"
  ];

  nixpkgs.config.allowUnfree = true; # Plex is unfree

  # Plex service
  users.groups.media = { };
  plexmodule = {
    enable = true;
    openFirewall = true;
  };

  networking = {
    hostName = "stream";
    nameservers = [ "1.1.1.1" "1.0.0.1" ];
    interfaces.eth0.ipv4.addresses = [{
      address = "10.23.15.11";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "10.23.15.1";
      interface = "eth0";
    };
    firewall.allowedTCPPorts = [ 32400 ]; # Plex
  };
}
