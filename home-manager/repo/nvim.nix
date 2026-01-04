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
		programs.nixvim = {
			enable = true;
			#plugins.lualine.enable = true;
			plugins = {
				lualine.enable = true;
				nvim-tree.enable = true;
			};
			opts = {
				number = true;
				numberwidth = 5;
				ruler = true;
				autowrite = true;
				shiftwidth = 2;
				tabstop = 2;
			};
		};
	};
}
