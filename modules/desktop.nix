{pkgs, lib, config, ...}:
with lib; let
  cfg = config.desktop;
in{
  imports = [
    ./repo/xserver.nix
    ./repo/sway.nix
		./repo/vpn.nix
		./repo/rdp.nix
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
				whether or not to enable nvidia drivers
			'';
		};

		intel.enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				whether or not to enable intel drivers
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
		rdp.enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable remote desktop
			'';
		};
  };

  config = mkIf cfg.enable {
    xservermodule = {
      enable = true;
			nvidia.enable = cfg.nvidia.enable;
			intel.enable = cfg.intel.enable;
    };
    swaymodule.enable = false;
		vpnmodule.enable = cfg.vpn.enable;
		rdpmodule.enable = cfg.rdp.enable;
  };
}
