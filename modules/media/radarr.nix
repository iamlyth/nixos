{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.radarrmodule;
  defaultPort = 7878;
  media = config.media;
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
    
    stateDir = mkOption {
      type = types.path;
      default = "${media.stateDir}/radarr";
      defaultText = literalExpression ''"''${media.stateDir}/radarr"'';
      example = "/nixarr/.state/radarr";
      description = ''
        The location of the state directory for the Radarr service.
      '';
    };


  };

  config = mkIf cfg.enable {
    services.radarr = {
      enable = true;
      user = "radarr";
      group = media.mediavalues.globals.libraryOwner.group;
      openFirewall = cfg.openFirewall;
    };
  }; 
}
