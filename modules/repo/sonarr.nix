{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.sonarrmodule;
  defaultPort = 7877;
  media = config.media;
in{
  options.sonarrmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Sonarr service.
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
      default = "${media.stateDir}/sonarr";
      defaultText = literalExpression ''"''${media.stateDir}/sonarr"'';
      example = "/data/.state/sonarr";
      description = ''
        The location of the state directory for the Sonarr service.
      '';
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Route sonarr traffic through the VPN.
      '';
    };


  };

  config = mkIf cfg.enable {
    services.sonarr = {
      enable = true;
      user = "sonarr";
      group = media.mediavalues.globals.libraryOwner.group;
      openFirewall = cfg.openFirewall;
    };

		# Enable and specify VPN namespace to confine service in.
		systemd.services.sonarr.vpnConfinement = mkIf cfg.vpn.enable {
			enable = true;
			vpnNamespace = "wg";
		};
		systemd.services.sonarr.serviceConfig = {
			Wants = [ "vpnNamespaces-wg.service" ];
			After = [ "vpnNamespaces-wg.service" ];
		};
  }; 
}
