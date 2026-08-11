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

    gui = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to enable the Mullvad GUI desktop app.
        Only takes effect on nixpkgs versions that have
        services.mullvad-vpn.gui (nixpkgs-unstable). On stable
        nixos-26.05 the gui sub-option does not exist and this
        setting is silently ignored.
      '';
    };
  };

  config = mkIf cfg.enable {
    services.mullvad-vpn = {
      enable = true;
      # Don't set package — nixpkgs split mullvad-vpn into mullvad (daemon)
      # and mullvad-vpn (GUI only). The module defaults to the right daemon
      # package now.
      # package = pkgs.mullvad-vpn;  # removed — triggers assertion in nixpkgs
    };
    # Add the GUI app via systemPackages instead of services.mullvad-vpn.gui,
    # which only exists on nixpkgs-unstable. Referencing that option on stable
    # nixos-26.05 throws even inside mkIf (the module system discovers the
    # path regardless of the condition). This is functionally equivalent:
    # on unstable, gui.enable just does `environment.systemPackages += [gui.package]`.
    environment.systemPackages = optional cfg.gui pkgs.mullvad-vpn;
  };
}
