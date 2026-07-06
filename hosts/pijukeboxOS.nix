{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/pitemplate.nix
    ../modules/librespot.nix
    ../modules/pibluetooth.nix
  ];

  networking.hostName = "controls-jukebox";

  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # System-wide PipeWire creates the socket owned by the `pipewire`
  # group, and ALSA control devices want `audio`. Both groups only
  # exist when pipewire is enabled, so they belong on the jukebox
  # host rather than the shared template.
  users.users.lalobied.extraGroups = [ "audio" "pipewire" ];

  # librespot runs with DynamicUser=true, so there's no persistent
  # users.users.librespot to add groups to. SupplementaryGroups on the
  # systemd unit is the right knob: the transient user that systemd
  # allocates each start gets these groups in addition to its own,
  # giving librespot access to PipeWire's ALSA shim. Without it,
  # playback dies with snd_pcm_open EACCES.
  systemd.services.librespot.serviceConfig.SupplementaryGroups = [
    "audio"
    "pipewire"
  ];

  librespotmodule = {
    enable = true;
    deviceName = "controls-jukebox";
  };

  pibluetoothmodule.enable = true;
}
