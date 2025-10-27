{ pkgs, lib, config, ... }:
{
  services.radarr = {
    enable = true;
    user = "radarr";
    group = "vboxsf";
  }; 
}
