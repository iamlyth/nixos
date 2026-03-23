{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.rdpmodule;
in{
  options.rdpmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable rdp.
        '';
    };
  };
  config = mkIf cfg.enable {
		# Enable the GNOME RDP components
		services.gnome.gnome-remote-desktop.enable = true;

		# Ensure the service starts automatically at boot
		systemd.services.gnome-remote-desktop = {
			wantedBy = [ "graphical.target" ];
		};

		systemd.user.services.gnome-remote-desktop-handover = {
			wantedBy = [ "gnome-session.target" ];
			overrideStrategy = "asDropin";
			unitConfig = {
				StopPropagatedFrom = "";
				RefuseManualStop = true;
			};
			serviceConfig = {
				TimeoutStopSec = "infinity";
			};
		};

		# Grant the gnome-remote-desktop system user GPU access
		# Required for DMA-BUF screen capture and VA-API hardware encoding
		users.users.gnome-remote-desktop.extraGroups = [ "render" "video" ];

		# Open the default RDP port (3389)
		networking.firewall.allowedTCPPorts = [ 3389 ];

		# Disable autologin to avoid session conflicts
		services.displayManager.autoLogin.enable = false;
		services.getty.autologinUser = null;

  };
}
