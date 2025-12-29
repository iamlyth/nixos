{ config, lib, pkgs, ...}:
with lib; let
  cfg = config.sabnzbdmodule;
  defaultPort = 6336;
  media = config.media;
in {
  options.sabnzbdmodule = {
    enable = mkEnableOption "Enable the SABnzbd service.";

    stateDir = mkOption {
      type = types.path;
      default = "${media.stateDir}/sabnzbd";
      defaultText = literalExpression ''"''${nixarr.stateDir}/sabnzbd"'';
      example = "/nixarr/.state/sabnzbd";
      description = ''
        The location of the state directory for the SABnzbd service.
      '';
    };

    package = mkPackageOption pkgs "sabnzbd" {};

    guiPort = mkOption {
      type = types.port;
      default = defaultPort;
      example = 9999;
      description = ''
        The port that SABnzbd's GUI will listen on for incomming connections.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      default = true;
      example = true;
      description = "Open firewall for SABnzbd";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Route SABnzbd traffic through the VPN.
      '';
    };

  };

  config = let
    ini-file-target = "${cfg.stateDir}/sabnzbd.ini";
    user-configs = {
      misc = {
        host =
          if cfg.openFirewall
          then "0.0.0.0"
          else "127.0.0.1";
        port = cfg.guiPort;
        permissions = "775";
      };
    };

    ini-base-config-file = pkgs.writeTextFile {
      name = "base-config.ini";
      text = lib.generators.toINI {} user-configs;
    };

    fix-config-permissions-script = pkgs.writeShellApplication {
      name = "sabnzbd-fix-config-permissions";
      runtimeInputs = with pkgs; [util-linux];
      text = ''
        if [ ! -f ${ini-file-target} ]; then
          echo 'FAILURE: cannot change permissions of ${ini-file-target}, file does not exist'
          exit 1
        fi

        chmod 600 ${ini-file-target}
        chown sabnzbd:media ${ini-file-target}
      '';
    };
    fix-user-permissions-script = pkgs.writeShellApplication {
      name = "sabnzbd-fix-user-permissions";
      runtimeInputs = with pkgs; [util-linux];
      text = ''
          chmod -R 777 ${cfg.stateDir};
          echo "chmod -R 777 ${cfg.stateDir};";
      '';
    };

  in
    mkIf cfg.enable {
      users = {
        users.sabnzbd = {
          isSystemUser = true;
          group = media.mediavalues.globals.libraryOwner.group;
        };
      };

      systemd.tmpfiles.rules = [
        "d '${cfg.stateDir}' 0700 sabnzbd root - -"
        "C ${cfg.stateDir}/sabnzbd.ini - - - - ${ini-base-config-file}"
        # Media dirs
        "d '${cfg.stateDir}/usenet'             0755 sabnzbd
        ${media.mediavalues.globals.libraryOwner.group} - -"
        "d '${cfg.stateDir}/usenet/.incomplete' 0755 sabnzbd ${media.mediavalues.globals.libraryOwner.group} - -"
        "d '${cfg.stateDir}/usenet/.watch'      0755 sabnzbd ${media.mediavalues.globals.libraryOwner.group} - -"
        "d '${cfg.stateDir}/usenet/manual'      0775 sabnzbd ${media.mediavalues.globals.libraryOwner.group} - -"
        "d '${cfg.stateDir}/usenet/lidarr'      0775 sabnzbd ${media.mediavalues.globals.libraryOwner.group} - -"
        "d '${cfg.stateDir}/usenet/radarr'      0775 sabnzbd ${media.mediavalues.globals.libraryOwner.group} - -"
        "d '${cfg.stateDir}/usenet/sonarr'      0775 sabnzbd ${media.mediavalues.globals.libraryOwner.group} - -"
        "d '${cfg.stateDir}/usenet/readarr'     0775 sabnzbd ${media.mediavalues.globals.libraryOwner.group} - -"
      ];

      services.sabnzbd = {
        enable = true;
        package = cfg.package;
        user = "sabnzbd";
        group = "media";
        configFile = "${cfg.stateDir}/sabnzbd.ini";
      };

      networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [cfg.guiPort];

      systemd.services.sabnzbd.serviceConfig = {
        ExecStartPre = lib.mkBefore [
          ("+" + fix-config-permissions-script + "/bin/sabnzbd-fix-config-permissions")
          ("+" + fix-user-permissions-script + "/bin/sabnzbd-fix-user-permissions")
					#(apply-user-configs-script + "/bin/sabnzbd-set-user-values")
        ];
        Restart = "on-failure";
        StartLimitBurst = 5;
      };

      # Enable and specify VPN namespace to confine service in.
			systemd.services.sabnzbd.vpnConfinement = mkIf cfg.vpn.enable {
  			enable = true;
  			vpnNamespace = "wg";
			};

			systemd.services.sabnzbd.serviceConfig = {
  			Wants = [ "vpnNamespaces-wg.service" ];
  			After = [ "vpnNamespaces-wg.service" ];
			};
		};
}
