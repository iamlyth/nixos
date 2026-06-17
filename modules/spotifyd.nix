{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.spotifydmodule;
in {
  options.spotifydmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether to enable the spotifyd Connect daemon, exposing this host
        as a Spotify Connect device (Premium account required).
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
  };

  config = mkIf cfg.enable {
    services.spotifyd = {
      enable = true;
      settings.global = {
        device_name = cfg.deviceName;
        bitrate = cfg.bitrate;
        device_type = "speaker";
        use_mpris = false;
      };
    };

    # Spotify Connect discovery is mDNS (Zeroconf), so the LAN needs to
    # see Avahi advertise the service, and the firewall has to let mDNS
    # and the discovery port through.
    services.avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        userServices = true;
      };
    };

    networking.firewall = {
      allowedUDPPorts = [ 5353 ];
      allowedTCPPorts = [ 57621 ];
    };
  };
}
