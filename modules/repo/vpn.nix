{pkgs, lib, config, ...}:
with lib; let
  cfg = config.vpnmodule;
in {
  options.vpnmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the vpn
        '';
    };
  };

  config = mkIf cfg.enable {
    services.mullvad-vpn = {
      enable = true;
      gui.enable = true;  # desktop GUI app (daemon comes from the mullvad package now)
      # Don't set package — nixpkgs split mullvad-vpn into mullvad (daemon)
      # and mullvad-vpn (GUI only). The module defaults to the right daemon
      # package now.
      # package = pkgs.mullvad-vpn;  # removed — triggers assertion in nixpkgs
    };
  };
}
