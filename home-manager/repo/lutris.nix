{ pkgs, lib, config, ... }:
with lib; let
	cfg = config.lutrismodule;
in{
	options.lutrismodule = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable the lutris service.
			'';
		};
	};
	config = mkIf cfg.enable {
		programs.lutris = {
			enable = true;
			extraPackages = with pkgs; [
				clonehero
			];
		};
	};
}
