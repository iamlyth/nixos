# hosts/logOS.nix
# Prometheus + Grafana monitoring LXC (CT 118).
#
# Secrets are loaded from ../secrets/monitoringsecrets.nix (gitignored — not in
# the public repo). Copy secrets/monitoringsecrets.example.nix to
# secrets/monitoringsecrets.nix and fill in real values before building.
{ config, lib, pkgs, ... }:

let
  secrets = import ../secrets/monitoringsecrets.nix;
in
{
  imports = [
    ../templates/lxctemplate.nix
    ../modules/repo/monitoring.nix
    ../modules/ghostty-terminfo.nix
  ];

  # Hardware (Proxmox LXC disk, CT 118).
  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" ];
  boot.kernelModules = [ "kvm-amd" ];

  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--118--disk--0";
    fsType = "ext4";
  };

  networking = {
    hostName = "log";
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.10.35";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "192.168.10.1";
      interface = "eth0";
    };
  };

  proxmoxLXC.manageHostName = true;

  monitoringmodule = {
    enable = true;
    grafanaSecretKey = secrets.grafanaSecretKey;
    haAuthToken = secrets.haAuthToken;
  };

  system.stateVersion = "26.05";
}
