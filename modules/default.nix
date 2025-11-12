{pkgs, lib, config, ...}:

{
  imports = [
    ./media.nix
    ./desktop.nix
    ./ssh.nix
  ];
}
