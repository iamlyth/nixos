{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.radarrmodule;
  defaultPort = 7878;
in{
  options.radarrmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Radarr service.
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
      services.radarr = {
      enable = true;
      user = "radarr";
      group = "vboxsf";
      openFirewall = cfg.enable;
    };
  }; 
}
