{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.jellyfinmodule;
  defaultPort = 8096;
in {
  options.jellyfinmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Jellyfin service.
      '';
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/jellyfin";
      example = "var/lib/jellyfin";
      description = ''
        The location of the state directory for Jellyfin.
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
    services.jellyfin = {
      enable = true;
      dataDir = cfg.dataDir;
      openFirewall = cfg.openFirewall;
      user = "jellyfin";
      group = "media";
    };
  };
}
