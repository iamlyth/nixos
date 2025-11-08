{pkgs, lib, config, ...}:

{
  imports = [
    ./media.nix
    ./ssh.nix
  ];
}
