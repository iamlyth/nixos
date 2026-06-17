{ config, lib, pkgs, ... }:
{
  imports = [
    ../modules/ssh.nix
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  # OpenZFS doesn't build cleanly against the +rpt1 Raspberry Pi kernel,
  # and we don't actually mount any ZFS volumes here.
  boot.supportedFilesystems.zfs = lib.mkForce false;

  # The +rpt1 RPi-Trading kernel doesn't ship a handful of modules the
  # default initrd thinks should exist (e.g. dw-hdmi). Tell
  # makeModulesClosure to tolerate misses instead of failing the build.
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = args:
        super.makeModulesClosure (args // { allowMissing = true; });
    })
  ];

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
