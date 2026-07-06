{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.librespotmodule;

  # spotifyd 0.4.x embeds librespot but hardwires the libmdns zeroconf
  # responder, which coexists badly with Avahi: both bind UDP 5353, a
  # client's unicast reconfirmation query is delivered to only one of
  # the two sockets, and libmdns mishandles what it receives. Phones
  # then drop the device as soon as the initial announcement's TTL
  # expires (~2 minutes). Plain librespot can register through the
  # already-running Avahi daemon instead, leaving exactly one correct
  # mDNS stack on the box, so the jukebox runs librespot directly.
  librespotPkg = pkgs.librespot.override {
    withAvahi = true;
    withMDNS = false;
  };

  playerEventFile = "/var/cache/librespot/last-player-event";

  # Runs as the librespot user on every player event; the cache
  # directory is the only path the DynamicUser service can write to.
  playerEventHook = pkgs.writeShellScript "librespot-player-event" ''
    echo "$PLAYER_EVENT $(${pkgs.coreutils}/bin/date +%s)" > ${playerEventFile}
  '';
in {
  options.librespotmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether to enable the librespot Connect daemon, exposing this
        host as a Spotify Connect device (Premium account required).
      '';
    };

    deviceName = mkOption {
      type = types.str;
      default = config.networking.hostName;
      example = "Living Room Pi";
      description = ''
        Name shown in the Spotify app's device picker.
      '';
    };

    bitrate = mkOption {
      type = types.enum [ 96 160 320 ];
      default = 320;
      description = ''
        Streaming bitrate in kbps.
      '';
    };

    zeroconfPort = mkOption {
      type = types.port;
      default = 5354;
      description = ''
        Fixed TCP port for Spotify Connect's zeroconf control channel.
        Pinned so the firewall can open a known port instead of the
        random high port librespot would otherwise choose.
      '';
    };

    idleResetMinutes = mkOption {
      type = types.int;
      default = 2;
      description = ''
        Restart librespot once the device is claimed by a user but has
        not played anything for this many minutes. librespot's zeroconf
        server records whoever connects as the "activeUser" and never
        clears it, and the Spotify app hides a Connect device whose
        activeUser is a different account. Without a reset, the first
        person to use the jukebox owns it until the process restarts,
        whether they played music or not. Set to 0 to disable.
      '';
    };
  };

  config = mkIf cfg.enable {
    systemd.services.librespot = {
      description = "librespot Spotify Connect daemon";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      after = [ "network-online.target" "avahi-daemon.service" "sound.target" ];

      serviceConfig = {
        # --disable-credential-cache keeps the daemon signed out across
        # restarts; a cached login makes the device invisible to every
        # other account, which defeats a shared jukebox.
        ExecStart = escapeShellArgs ([
          "${librespotPkg}/bin/librespot"
          "--name" cfg.deviceName
          "--backend" "alsa"
          "--bitrate" (toString cfg.bitrate)
          "--device-type" "speaker"
          "--zeroconf-port" (toString cfg.zeroconfPort)
          "--zeroconf-backend" "avahi"
          "--disable-credential-cache"
          "--cache" "/var/cache/librespot"
        ] ++ optionals (cfg.idleResetMinutes != 0) [
          "--onevent" "${playerEventHook}"
        ]);
        Restart = "always";
        RestartSec = 5;
        DynamicUser = true;
        CacheDirectory = "librespot";
        SupplementaryGroups = [ "audio" ];
        # Drop the previous run's event file so a fresh start can't
        # trigger an immediate idle reset. The "+" runs it as root
        # since the file belongs to the previous transient user.
        ExecStartPre = "+${pkgs.coreutils}/bin/rm -f ${playerEventFile}";
      };
    };

    # Once someone has used the jukebox, librespot keeps reporting them
    # as the activeUser over zeroconf forever, which hides the device
    # from every other account. This checker decides from two signals:
    # getInfo on the discovery endpoint says whether anyone currently
    # claims the device (empty on a fresh, unclaimed process, so this
    # can't loop), and the hook-written event file says whether music
    # is flowing. A claimed device with no playback event for the
    # configured window gets restarted, which clears the claim.
    # Playback-ish events block the restart regardless of age, because
    # a long track can go many minutes without emitting anything new.
    systemd.services.librespot-idle-reset = mkIf (cfg.idleResetMinutes != 0) {
      description = "Release librespot's active-user claim after idle";
      path = [ pkgs.coreutils pkgs.systemd pkgs.curl pkgs.jq ];
      serviceConfig.Type = "oneshot";
      script = ''
        state=${playerEventFile}
        [ -e "$state" ] || exit 0

        info=$(curl -sf --max-time 5 \
          'http://127.0.0.1:${toString cfg.zeroconfPort}/?action=getInfo') || exit 0
        active_user=$(printf '%s' "$info" | jq -r '.activeUser // empty') || exit 0
        [ -n "$active_user" ] || exit 0

        read -r event ts < "$state" || exit 0
        case "$event" in
          playing|loading|preloading|preload_next|track_changed| \
          end_of_track|seeked|position_correction|play_request_id_changed| \
          volume_changed|shuffle_changed|repeat_changed|auto_play_changed| \
          filter_explicit_content_changed)
            exit 0 ;;
        esac

        now=$(date +%s)
        if [ "$((now - ts))" -ge "$((${toString cfg.idleResetMinutes} * 60))" ]; then
          rm -f "$state"
          systemctl restart librespot.service
        fi
      '';
    };

    systemd.timers.librespot-idle-reset = mkIf (cfg.idleResetMinutes != 0) {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "1min";
      };
    };

    # librespot registers _spotify-connect._tcp through avahi-daemon
    # over D-Bus, so Avahi must run and publishing must be on. Avahi
    # answers queries on both IPv4 and IPv6, which also covers the
    # office networks where libmdns only ever answered over IPv6.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        userServices = true;
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ 5353 ];
      allowedTCPPorts = [ 57621 cfg.zeroconfPort ];
    };
  };
}
