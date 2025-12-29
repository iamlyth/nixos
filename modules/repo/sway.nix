{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.swaymodule;
in{
  options.swaymodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the sway.
        '';
    };
  };
  config = mkIf cfg.enable {
    programs.sway = {
      enable = true;
      wrapperFeatures.gtk = true;
      extraOptions = [ "--unsupported-gpu" ];
    };
    services.gnome.gnome-keyring.enable = true;

    environment.systemPackages = with pkgs; [
      grim #for screenshots
      slurp #screenshops
      wl-clipboard # wl-copy and wl-paste for copy/paste from stdin / stdout
      mako # notification system developed by swaywm maintainer
    ];
    security.polkit.enable = true; #sway stuff
  };
}
