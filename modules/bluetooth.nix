{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.bluetoothmodule;
in {
  options.bluetoothmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Headless Bluetooth audio: BlueZ with auto-reconnect of trusted
        devices, PipeWire (system-wide) as the audio stack so BT sinks
        are reachable without a logged-in user, and bluetuith as a TUI
        for pairing/connecting over SSH.
      '';
    };
  };

  config = mkIf cfg.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.AutoEnable = true;
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

    environment.systemPackages = with pkgs; [
      bluetuith
      bluez-tools
    ];
  };
}
