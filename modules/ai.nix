{ lib, config, ... }:
with lib; let
  cfg = config.ai;
in {
  imports = [
    ./repo/ollama.nix
    ./repo/openwebui.nix
    ./repo/llama-server.nix
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

    # llama.cpp Vulkan server with MTP — the 70+ t/s path for A3B models.
    # Runs alongside Ollama on a separate port. Ollama handles chat/webui;
    # this serves coding/agent workloads that benefit from MTP spec decoding.
    llamaServer = {
      enable = mkEnableOption "llama.cpp Vulkan server (MTP speculative decoding)";

      modelPath = mkOption {
        type = types.str;
        description = "Absolute path to the main GGUF model file (MTP-grafted).";
      };

      port = mkOption {
        type = types.port;
        default = 8001;
        description = "Port for llama-server (separate from Ollama's 11434).";
      };

      contextSize = mkOption {
        type = types.int;
        default = 262144;
        description = "Context window size.";
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

    llamaservermodule = mkIf cfg.llamaServer.enable {
      enable = true;
      modelPath = cfg.llamaServer.modelPath;
      port = cfg.llamaServer.port;
      contextSize = cfg.llamaServer.contextSize;
    };
  };
}
