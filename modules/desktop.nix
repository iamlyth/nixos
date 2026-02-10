{pkgs, lib, config, ...}:
with lib; let
  cfg = config.desktop;
in{
  imports = [
    ./desktop/xserver.nix
    ./desktop/sway.nix
  ];
  options.desktop = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Desktop Environment.
        '';
    };
  };

  config = mkIf cfg.enable {
    xservermodule = {
      enable = true;
    };
    swaymodule.enable = false;
  };
}
