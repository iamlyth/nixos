{ pkgs, lib, config, ... }:
with lib; let
	cfg = config.nvimmodule;
in{
	options.nvimmodule = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable nvim.
			'';
		};
	};
	config = mkIf cfg.enable {
		programs.neovim = {
			enable = true;
		};
	};
}
