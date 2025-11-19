{pkgs, lib, config, ...}:
with lib; let
  cfg = config.media;
  defaultMediaDir = "/media/";
in{
  imports = [
    ./media/plex.nix
    ./media/radarr.nix
    ./media/sabnzbd.nix
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
    };

    ### SABNZBD
    sabnzbdmodule = {
      enable = true;
      openFirewall = true;
      vpn.enable = true;
    };

    vpnNamespaces.wg = {
        enable = true;
        openVPNPorts = [{
        	port = 6336;
        	protocol = "both";
        }];
        accessibleFrom = [
            "192.168.0.0/16"
            "127.0.0.1"
        ];
        wireguardConfigFile = "/data/.secret/vpn/wg.conf";
    };
  };
}
