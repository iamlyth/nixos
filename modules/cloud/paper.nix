{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.papermodule;
in{
  options.papermodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Paper service.
        '';
    };
    mediaDir = mkOption {
      type = types.path;
      default = "/run/media/familyvault/";
      example = "var/lib/plex";
      description = ''
        The location of the state directory for Paperless.
      '';
    };
  };
  config = mkIf cfg.enable {
    users.users.paper = {
  		isSystemUser = true;
  		group = "vault";
  		extraGroups = [ "vault" ];
  		shell = pkgs.shadow;
    };
  	services.paperless = {
  		enable = true;
  		port=28981;
  		address = "0.0.0.0";
  		mediaDir = "/run/media/familyvault/";
  		user = "paper";
  		settings = {
  			PAPERLESS_URL = "https://paper.tatchi.org";
  		};
  	};
  	users.groups.vault = { gid = 1005; };
    systemd.services.paperless = {
      requires = [ "run-media-familyvault.mount" ];  # Paperless will pull in the mount
      after    = [ "run-media-familyvault.mount" ];  # Paperless starts only after the mount
			serviceConfig = {
    		ReadWritePaths = [ "/run/media/familyvault" ];
  		};
    };
  };
}
