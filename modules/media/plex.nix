{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.plexmodule;
  defaultPort = 32400;
in{
  options.plexmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Plex service.
        '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/plex";
      example = "var/lib/plex";
      description = ''
        The location of the state directory for Plex.

        Setting this path to any path where the subpath is not owned by
        root will fail.
      
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      example = true;
      description = ''
        Whether or not to expose the firewall 
        '';
    };
  };
  config = mkIf cfg.enable {
    services.plex = {
      enable = true;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
      user = "plex";
      group = "vboxsf";
    };
  };
}
