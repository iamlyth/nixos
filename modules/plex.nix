{ pkgs, lib, config, ... }:
{
  services.plex = {
    enable = true;
    dataDir = "/var/lib/plex";
    openFirewall = true;
    user = "plex";
    group = "vboxsf";
  };
}
