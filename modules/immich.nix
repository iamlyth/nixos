{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.immichmodule;
in{
  options.immichmodule = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable the Immich.
			'';
		};
  };
  config = mkIf cfg.enable {
		services.immich = {
			enable = true;
  		port = 2283;
			host = "0.0.0.0";
			mediaLocation = "/run/media/familyvault/immich/";
			openFirewall = true;	
		};	
  };
}
