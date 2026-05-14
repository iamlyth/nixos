 { config, lib, pkgs, ... }:

{
  imports = [
  # <nixos-wsl/modules>
  ];
  wsl.enable = true;
  wsl.defaultUser = "lalobied";
  wsl.wslConf = {
    automount.enabled = lib.mkForce true;
  };

  nix.settings.experimental-features = ["nix-command" "flakes"];


  nixpkgs.config.allowUnfree = true; #  allow proprietary packages

  # SHELL
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  environment.systemPackages = with pkgs; [
    git
    eza
    fzf #  needed for zsh auto suggestion
    ripgrep
    uv
    pandoc
    poppler-utils
  ];

  # fix for nix-ld
  programs.nix-ld.enable = true;

  # timezone
  time.timeZone = "US/Michigan";

  # where was I and what am I made of?  
  nixpkgs.hostPlatform = "x86_64-linux";
  system.stateVersion = "25.11";
}
