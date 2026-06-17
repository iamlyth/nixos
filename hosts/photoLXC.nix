# hosts/photoLXC.nix
{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/lxctemplate.nix
    ../modules/immich.nix
  ];

  # Hardware (Proxmox VM disk + CIFS family vault).
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" ];
  boot.kernelModules = [ "kvm-intel" ];

  fileSystems."/" = {
    device = "/dev/mapper/pve-vm--105--disk--0";
    fsType = "ext4";
  };

  fileSystems."/mnt/familyvault" = {
    device = "//192.168.5.114/familyvault";
    fsType = "cifs";
  };

  environment.systemPackages = with pkgs; [ eza ];

  immichmodule.enable = true;
}
