{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.pibluetoothmodule;
in {
  options.pibluetoothmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Headless Bluetooth-audio extras on top of nixos-raspberrypi's
        raspberry-pi-4.bluetooth module (which enables hardware.bluetooth
        and `krnbt=on` for us): BlueZ auto-reconnect of trusted devices,
        system-wide PipeWire so BT sinks work without a logged-in user,
        and bluetuith as a TUI for pairing over SSH.
      '';
    };
  };

  config = mkIf cfg.enable {
    # The base bluetooth module already sets hardware.bluetooth.enable;
    # we layer on power-on-at-boot, auto-reconnect for trusted devices,
    # and the audio profile roles. Without General.Enable including
    # Source/Sink/Media/Socket, BlueZ won't register A2DP and connecting
    # to a speaker fails with "Protocol not available".
    hardware.bluetooth = {
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
        # AutoEnable moved from [General] to [Policy] in BlueZ 5.65.
        Policy.AutoEnable = true;
      };
    };

    # System-wide PipeWire so audio works without a desktop session.
    # Officially "not recommended" upstream, but it's the standard
    # path for a headless audio box.
    services.pipewire = {
      enable = true;
      systemWide = true;
      alsa.enable = true;
      pulse.enable = true;
      wireplumber.enable = true;
    };

    # systemWide PipeWire is socket-activated, and WirePlumber's NixOS
    # unit doesn't carry WantedBy=multi-user.target on its own — so at
    # boot, nothing pokes PipeWire's socket, PipeWire never starts,
    # WirePlumber never starts, BlueZ has no A2DP backend, and audio
    # connect fails with "Protocol not available". Force-attach both
    # to multi-user.target so they come up unconditionally.
    systemd.services.pipewire.wantedBy     = [ "multi-user.target" ];
    systemd.services.wireplumber.wantedBy  = [ "multi-user.target" ];

    environment.systemPackages = with pkgs; [
      bluetuith
      bluez-tools
    ];
  };
}
