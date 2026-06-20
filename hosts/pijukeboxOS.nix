{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/pitemplate.nix
    ../modules/spotifyd.nix
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

  # services.spotifyd runs with DynamicUser=true, so there's no
  # persistent users.users.spotifyd to add groups to. SupplementaryGroups
  # on the systemd unit is the right knob — the transient user that
  # systemd allocates each start gets these groups in addition to its
  # own, giving spotifyd access to PipeWire's ALSA shim without it,
  # playback dies with snd_pcm_open EACCES.
  systemd.services.spotifyd.serviceConfig.SupplementaryGroups = [
    "audio"
    "pipewire"
  ];

  # ffmpeg-headless pulls in openapv 0.2.1.2 on ffmpeg ≥ 8.0, but
  # openapv's GitHub tarball was regenerated upstream and nixos-26.05
  # hasn't backported the new hash. Even cache.nixos.org can't supply
  # this source derivation, so the build can't proceed without
  # rebuilding ffmpeg + the whole closure downstream of it. The
  # jukebox doesn't need an APV encoder; drop the dependency.
  # Remove this when nixos-26.05 picks up the openapv hash fix.
  nixpkgs.overlays = [
    (final: prev: {
      ffmpeg-headless = prev.ffmpeg-headless.override {
        withOpenapv = false;
      };
    })
  ];

  spotifydmodule = {
    enable = true;
    deviceName = "controls-jukebox";
  };

  pibluetoothmodule.enable = true;
}
