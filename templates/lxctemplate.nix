# templates/lxctemplate.nix
{ modulesPath, config, lib, pkgs, ... }:
{
  imports = [
    ../modules/ssh.nix
    (modulesPath + "/virtualisation/proxmox-lxc.nix")
  ];

  boot.isContainer = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  systemd.suppressedSystemUnits = [
    "dev-mqueue.mount"
    "sys-kernel-debug.mount"
    "sys-fs-fuse-connections.mount"
  ];

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "lalobied" ];

  environment.systemPackages = with pkgs; [
    git
    vim
    cifs-utils
  ];

  sshmodule = {
    enable = true;
    port = [ 55 ];
  };

  time.timeZone = "US/Michigan";

  users.users.lalobied = {
    isNormalUser = true;
    home = "/Users/lalobied";
    extraGroups = [ "wheel" ];
  };

  system.stateVersion = "25.11";
}
