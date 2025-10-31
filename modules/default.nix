{pkgs, lib, config, ...}:
{
  imports = [
    ./plex.nix
    ./radarr.nix
  ];
}
