{ lib, config, ... }:
with lib; let
  cfg = config.ai;
in {
  imports = [
    ./repo/ollama.nix
    ./repo/openwebui.nix
  ];

  options.ai = {
    enable = mkEnableOption "AI services";

    acceleration = mkOption {
      type = types.enum [ "rocm" "jetson-cuda" ];
      description = "GPU acceleration backend for ollama.";
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
      description = "Stop ollama after this idle period. Null disables the timeout.";
    };

    openwebui = {
      enable = mkEnableOption "Open WebUI frontend";

      port = mkOption {
        type = types.port;
        default = 8080;
        description = "Port for Open WebUI to listen on.";
      };

      corsOrigin = mkOption {
        type = types.str;
        default = "*";
        example = "https://ai.example.com";
        description = "Value for CORS_ALLOW_ORIGIN.";
      };
    };
  };

  config = mkIf cfg.enable {
    ollamamodule = {
      enable = true;
      acceleration = cfg.acceleration;
      models = cfg.models;
      idleTimeout = cfg.idleTimeout;
    };

    openwebuimodule = mkIf cfg.openwebui.enable {
      enable = true;
      port = cfg.openwebui.port;
      corsOrigin = cfg.openwebui.corsOrigin;
    };
  };
}
