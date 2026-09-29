# hosts/photoLXC.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/lxctemplate.nix
    ../modules/immich.nix
    ../modules/ghostty-terminfo.nix
  ];

  # Hardware (Proxmox VM disk + CIFS family vault).
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--105--disk--0";
    fsType = "ext4";
  };

  fileSystems."/mnt/familyvault" = {
    device = "//192.168.10.50/familyvault";
    fsType = "cifs";
  };

  environment.systemPackages = with pkgs; [ eza ];

  immichmodule.enable = true;

  networking = {
    hostName = "immich";
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.10.14";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "192.168.10.1";
      interface = "eth0";
    };
  };
}
