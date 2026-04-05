{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.xservermodule;
in{
  options.xservermodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the wayland/gnome service.
        '';
    };
		nvidia.enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				whether or not to enable nvidia drivers
			'';
		};

		intel.enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				whether or not to enable intel drivers
			'';
		};
  };
  config = mkIf cfg.enable {
    hardware.graphics = { #renamed from hardware.opengl
      enable = true;
    };
    hardware.nvidia = mkIf cfg.nvidia.enable {
      modesetting.enable = true;
      package =
        config.boot.kernelPackages.nvidiaPackages.stable;
        nvidiaSettings = true;
        open = false;
    };
		
    services.xserver = {
      #enable graphical interface
      enable = true;
      #enable GNOME
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      #keymap in X11
      xkb = {
        layout = "us";
        variant = "";
      };
      videoDrivers = if cfg.nvidia.enable then ["nvidia"]
				else if cfg.intel.enable then ["intel"]
				else lib.mkDefault [];
      excludePackages = [pkgs.xterm];
    };

    environment.gnome.excludePackages = (with pkgs; [
      epiphany #browser
      gnome-text-editor #text editor
      gnome-tour #tour app
      xterm #xterminal emulator
      gnome-music #music app
      simple-scan #scanner
    ]);

  };
}
