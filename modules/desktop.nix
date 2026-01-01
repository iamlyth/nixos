{pkgs, lib, config, ...}:
with lib; let
  cfg = config.desktop;
in{
  imports = [
    ./repo/xserver.nix
    ./repo/sway.nix
		./repo/vpn.nix
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
		nvidia.enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable nvidia Drivers
			'';
		};
		
		vpn.enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable Mullvad VPN
			'';
		};
  };

  config = mkIf cfg.enable {
    xservermodule = {
      enable = true;
			nvidia.enable = cfg.nvidia.enable;
    };
    swaymodule.enable = false;
		vpnmodule.enable = cfg.vpn.enable;
  };
}
