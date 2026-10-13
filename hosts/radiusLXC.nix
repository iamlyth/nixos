# hosts/radiusLXC.nix
# FreeRADIUS + daloRADIUS LXC for UniFi MAC-based VLAN assignment.
#
# Secrets are loaded from ../secrets/radiussecrets.nix (gitignored — not in
# the public repo). Copy secrets/radiussecrets.example.nix to
# secrets/radiussecrets.nix and fill in real passwords before building.
{ config, lib, pkgs, ... }:

let
  secrets = import ../secrets/radiussecrets.nix;
in
{
  imports = [
    ../templates/lxctemplate.nix
    ../modules/repo/freeradius.nix
    ../modules/ghostty-terminfo.nix
  ];

  # Hardware (Proxmox LXC disk, CT 117).
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" ];
  boot.kernelModules = [ "kvm-amd" ];

  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--117--disk--0";
    fsType = "ext4";
  };

  networking = {
    hostName = "radius";
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.10.22";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "192.168.10.1";
      interface = "eth0";
    };
  };

  # The proxmox-lxc module force-blanks networking.hostName (mkForce "")
  # so Proxmox's /etc/hostname wins. That empty hostName breaks the httpd
  # module's global ServerName directive ("ServerName takes one argument").
  # manageHostName lets Nix own the hostname so hostName = "radius" above
  # actually applies.
  proxmoxLXC.manageHostName = true;

  radiusmodule = {
    enable = true;
    dbPassword = secrets.dbPassword;
    radiusSecret = secrets.radiusSecret;
    unifiSubnet = "192.168.1.0/24";
  };

  # This container was first built from nixos-26.05 — pin the actual
  # install version (template defaults to 25.11 for the older LXCs).
  system.stateVersion = "26.05";
}