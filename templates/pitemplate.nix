{ config, lib, pkgs, ... }:
{
  imports = [
    ../modules/ssh.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # OpenZFS doesn't build cleanly against the +rpt1 Raspberry Pi kernel,
  # and we don't actually mount any ZFS volumes here.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  networking.hostName = lib.mkDefault "pitemplate";
  networking.useDHCP = lib.mkDefault true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  sshmodule = {
    enable = true;
    port = [ 22 ];
  };

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

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
