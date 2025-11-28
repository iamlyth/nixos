{config, pkgs, ...}:
{
  home.packages = with pkgs; [
		# Ensure the extension packages themselves are present
		gnomeExtensions.blur-my-shell
		gnomeExtensions.gsconnect
		gnomeExtensions.system-monitor
		gnomeExtensions.night-theme-switcher
		gnomeExtensions.forge
		gnomeExtensions.appindicator
  ];
  dconf = {
		enable = true;
		settings."org/gnome/shell" = {
			disable-user-extensions = false;
			enabled-extensions = with pkgs.gnomeExtensions; [
				blur-my-shell.extensionUuid
				gsconnect.extensionUuid
				system-monitor.extensionUuid
				night-theme-switcher.extensionUuid
				forge.extensionUuid
				appindicator.extensionUuid
			];
		};
	};
}
