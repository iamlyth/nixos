{config, pkgs, ...}:
{
  home.packages = with pkgs; [
		# Ensure the extension packages themselves are present
		gnomeExtensions.blur-my-shell
		gnomeExtensions.gsconnect
		gnomeExtensions.night-theme-switcher
		gnomeExtensions.forge
		gnomeExtensions.appindicator #for system tray (discord/steam)
		gnomeExtensions.display-configuration-switcher
		gnomeExtensions.vitals
  ];
  dconf = {
		enable = true;
		settings."org/gnome/shell" = {
			disable-user-extensions = false;
			enabled-extensions = with pkgs.gnomeExtensions; [
				blur-my-shell.extensionUuid
				gsconnect.extensionUuid
				night-theme-switcher.extensionUuid
				forge.extensionUuid
				appindicator.extensionUuid
				display-configuration-switcher.extensionUuid
				vitals.extensionUuid
			];
		};
	};
}
