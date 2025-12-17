{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.pgsqlmodule;
in{
  options.pgsqlmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the PostgreSQL Database.
        '';
    };
  };
  config = mkIf cfg.enable {
		services.postgresql = {
			enable = true;
			ensureDatabases = [ "paperless" ];
			authentication = pkgs.lib.mkOverride 10 ''
				#...
				#type	database	DBuser	origin-address	auth-method
				local	all				all			trust
				# ipv4
				host	all				all			127.0.0.1/32		trust
				# ipv6
				host	all				all			::1/128					trust	
			'';
  	};	
  };
}
