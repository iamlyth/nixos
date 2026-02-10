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
  };
  config = mkIf cfg.enable {
    hardware.graphics = { #renamed from hardware.opengl
      enable = true;
    };
    hardware.nvidia = {
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
      videoDrivers = ["nvidia"]; #with hardware acceleration
      excludePackages = [pkgs.xterm];
    };

    environment.gnome.excludePackages = (with pkgs; [
      snapshot #Camera
      gnome-calendar #calendar
      gnome-contacts #contacts
      epiphany #browser
      gnome-text-editor #text editor
      gnome-tour #tour app
      xterm #xterminal emulator
      geary #gnome email
      gnome-music #music app
      simple-scan #scanner
    ]);
  };
}
