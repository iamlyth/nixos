{ config, lib, pkgs, ... }:
with lib; let
  cfg = config.cloud;
in{
  imports = [
    ./cloud/paper.nix
		./cloud/postgresql.nix
		./cloud/immich.nix
  ];
  options.cloud = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable cloud services.
			'';
		};
  };
  config = mkIf cfg.enable {
		pgsqlmodule = {
			enable = true;
		};
		immichmodule = {
			enable = true;
		};
		papermodule = {
			enable = true;
		};
  };
}
