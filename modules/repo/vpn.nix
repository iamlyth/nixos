{pkgs, lib, config, ...}:
with lib; let
	cfg = config.vpnmodule;
in{
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
			package = pkgs.mullvad-vpn;
		};
	};
}
