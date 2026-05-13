{ lib, config, pkgs, jail-nix, ... }:
with lib;
let
  cfg = config.pimodule;
in
{
	options.pimodule = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable picoding agent
			'';
		};
	};
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      pi-coding-agent
    ];
  };
}
