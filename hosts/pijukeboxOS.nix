{ config, lib, pkgs, ... }:
{
  imports = [
    ../templates/pitemplate.nix
    ../modules/spotifyd.nix
    ../modules/bluetooth.nix
  ];

  networking.hostName = "pijukeboxOS";

  spotifydmodule = {
    enable = true;
    deviceName = "pijukeboxOS";
  };

  bluetoothmodule.enable = true;
}
