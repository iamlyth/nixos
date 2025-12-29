{pkgs, lib, config, ...}:
with lib; let
  cfg = config.media;
  defaultMediaDir = "/media/";
in{
  imports = [
    ./repo/plex.nix
    ./repo/radarr.nix
    ./repo/sabnzbd.nix
		./repo/sonarr.nix
  ];
  options.media = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the all media service.
        '';
    };
	
    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable vpn
        '';
    };

    mediaUsers = mkOption {
      type = with types; listOf str;
      default = [];
      example = ["user"];
      description = ''
        extra users to add to media group.
      '';
    };

    mediaDir = mkOption {
      type = types.path;
      default = "/run/media/media";
      example = "/data/media";
      description = ''
        where all the good stuff lives
      '';
    };

    stateDir = mkOption {
      type = types.path;
      default = "/data/.state/media";
      example = "/media/.state";
      description = ''
        The location of the state directory for the services.
      '';
    };

    mediavalues.globals = mkOption {
      type = types.attrs;
      default ={};
      description = "media specific stuff";
    };
  };

  config = mkIf cfg.enable {
    media.mediavalues.globals = {
      libraryOwner.group = "media";
    };

    ### PLEX
    plexmodule = {
      enable = true;
    };

    ### RADARR
    radarrmodule = {
      enable = true;
      vpn.enable = cfg.vpn.enable;
    };

    ### SONARR
    sonarrmodule = {
      enable = true;
      vpn.enable = cfg.vpn.enable;
    };

    ### SABNZBD
    sabnzbdmodule = {
      enable = true;
      openFirewall = true;
      vpn.enable = cfg.vpn.enable;
    };

    vpnNamespaces.wg = mkIf cfg.vpn.enable {
      enable = true;
      openVPNPorts = [
			{
      	port = 6336;
        protocol = "both";
      }
			{
      	port = 8989;
        protocol = "both";
      }
			{
      	port = 7878;
        protocol = "both";
      }];
      accessibleFrom = [
        "192.168.0.0/16"
        "127.0.0.1"
      ];
			portMappings = [
			{
				from = 6336;
				to = 6336;
			}
			{
				from = 8989;
				to = 8989;
			}
			{
				from = 7878;
				to = 7878;
			}];			
      wireguardConfigFile = "/data/.secret/vpn/wg.conf";
    };

		services.nginx = mkIf cfg.vpn.enable {
			enable = true;
			recommendedTlsSettings = true;
			recommendedOptimisation = true;
			recommendedGzipSettings = true;
			virtualHosts."sabnzbd" = {
				listen = [{
					addr = "0.0.0.0";
					port = 6336;
				}];
				locations."/" = {
					recommendedProxySettings = true;
					proxyWebsockets = true;
					proxyPass = "http://192.168.15.1:6336";
				};
			};
			virtualHosts."radarr" = {
				listen = [{
					addr = "0.0.0.0";
					port = 7878;
				}];
				locations."/" = {
					recommendedProxySettings = true;
					proxyWebsockets = true;
					proxyPass = "http://192.168.15.1:7878";
				};
			};
			virtualHosts."sonarr" = {
				listen = [{
					addr = "0.0.0.0";
					port = 8989;
				}];
				locations."/" = {
					recommendedProxySettings = true;
					proxyWebsockets = true;
					proxyPass = "http://192.168.15.1:8989";
				};
			};
		};
		systemd.services.nginx.serviceConfig = {
			Wants = [ "sabnzbd.service" "radarr.service" ];
			After = [ "sabnzbd.service" "radarr.service" ];
		};
  };
}
