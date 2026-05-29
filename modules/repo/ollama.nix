{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.ollamamodule;

  jetsonFixRules = pkgs.writeTextFile {
    name = "99-z-jetson-fix";
    destination = "/lib/udev/rules.d/99-z-jetson-fix.rules";
    text = ''
      KERNEL=="nvhost-sched-gpu", GROUP="video", MODE="0660"
    '';
  };

  ollamaPackage = {
    rocm = pkgs.ollama-rocm;
    jetson-cuda = pkgs.ollama-cuda;
  }.${cfg.acceleration};
in {
  options.ollamamodule = {
    enable = mkEnableOption "ollama LLM server";

    acceleration = mkOption {
      type = types.enum [ "rocm" "jetson-cuda" ];
      description = "GPU acceleration backend to use.";
    };

    models = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Models to preload on startup.";
    };

    idleTimeout = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "5min";
      description = "Stop the service after this idle period. Null disables the timeout.";
    };
  };

  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = ollamaPackage;
      host = "0.0.0.0";
      loadModels = cfg.models;
      environmentVariables = mkMerge [
        (mkIf (cfg.acceleration == "rocm") {
          HSA_OVERRIDE_GFX_VERSION = "11.0.0";
        })
        (mkIf (cfg.acceleration == "jetson-cuda") {
          OLLAMA_KEEP_ALIVE = "-1";
          LD_LIBRARY_PATH = "${pkgs.ollama-cuda}/lib/ollama:/run/opengl-driver/lib";
        })
      ];
    };

    systemd.services.ollama = mkMerge [
      (mkIf (cfg.acceleration == "rocm") {
        wantedBy = mkForce [];
        serviceConfig.TimeoutIdleSec = mkIf (cfg.idleTimeout != null) cfg.idleTimeout;
      })
      (mkIf (cfg.acceleration == "jetson-cuda") {
        serviceConfig = {
          DevicePolicy = mkForce "auto";
          DeviceAllow = mkForce [];
          PrivateDevices = mkForce false;
          SupplementaryGroups = [ "video" ];
          PrivateUsers = mkForce false;
          ProtectProc = mkForce "default";
        };
      })
    ];

    services.udev.packages = mkIf (cfg.acceleration == "jetson-cuda") [ jetsonFixRules ];
    services.udev.extraRules = mkIf (cfg.acceleration == "jetson-cuda") ''
      SUBSYSTEM=="nvidia-gpu", GROUP="video", MODE="0660"
      KERNEL=="nvmap", GROUP="video", MODE="0660"
    '';
    environment.etc."udev/rules.d/99-z-jetson-fix.rules" = mkIf (cfg.acceleration == "jetson-cuda") {
      text = ''
        KERNEL=="nvhost-sched-gpu", GROUP="video", MODE="0660"
      '';
    };

    networking.firewall.allowedTCPPorts = [ 11434 ];
  };
}
