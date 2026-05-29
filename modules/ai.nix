{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.aimodule;
  jetsonFixRules = pkgs.writeTextFile {
    name = "99-z-jetson-fix";
    destination = "/lib/udev/rules.d/99-z-jetson-fix.rules";
    text = ''
      KERNEL=="nvhost-sched-gpu", GROUP="video", MODE="0660"
    '';
  };
in {
  options.aimodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable ai.
        '';
    };

    openwebui = mkOption {
      type = types.bool;
      default = true;
      example = true;
      description = ''
        Whether or not to enable openwebui
        '';
    };
  };

  config = mkIf cfg.enable {
    services.ollama = {
			enable = true;
			package = pkgs.ollama-cuda;
			host = "0.0.0.0";
			environmentVariables = {
				OLLAMA_KEEP_ALIVE = "-1";
				LD_LIBRARY_PATH = "${pkgs.ollama-cuda}/lib/ollama:/run/opengl-driver/lib";
			};
		};
		systemd.services.ollama.serviceConfig = {
			DevicePolicy = lib.mkForce "auto";  # ← clear DevicePolicy=closed from nixpkgs
			DeviceAllow = lib.mkForce [];       # ← nuke nixpkgs DeviceAllow entries entirely
			PrivateDevices = lib.mkForce false;
			SupplementaryGroups = [ "video" ];
			PrivateUsers = lib.mkForce false;
			ProtectProc = lib.mkForce "default";
		};
		services.udev.packages = [ jetsonFixRules ];
		services.udev.extraRules = ''
			SUBSYSTEM=="nvidia-gpu", GROUP="video", MODE="0660"
			KERNEL=="nvmap", GROUP="video", MODE="0660"
		'';

		environment.etc."udev/rules.d/99-z-jetson-fix.rules".text = ''
			KERNEL=="nvhost-sched-gpu", GROUP="video", MODE="0660"
		'';
		networking.firewall.allowedTCPPorts = [ 11434 ];
  };
}
