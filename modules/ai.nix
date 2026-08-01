# AI services module. Coordinates Ollama, Open WebUI, and llama-server.
#
# Desktop: Ollama + Open WebUI auto-start at boot. llama-server starts
#   manually for MTP 81 t/s inference. Open WebUI connects to both.
# Tatchi: Ollama + Open WebUI auto-start. No llama-server.
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
      default = "rocm";
      description = "GPU acceleration backend for ollama.";
    };

    ollama = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Ollama LLM server.";
      };

      autoStart = mkOption {
        type = types.bool;
        default = true;
        description = "Auto-start Ollama at boot.";
      };
    };

    models = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Ollama models to preload on startup.";
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
        description = "Port for Open WebUI.";
      };

      corsOrigin = mkOption {
        type = types.str;
        default = "*";
        example = "https://ai.example.com";
        description = "Value for CORS_ALLOW_ORIGIN.";
      };

      openaiBaseUrl = mkOption {
        type = types.str;
        default = "http://localhost:8001/v1";
        description = "OpenAI-compatible endpoint for llama-server. Open WebUI connects to both Ollama and this.";
      };
    };

    # llama.cpp Vulkan server with MTP speculative decoding.
    # Does not auto-start — run: sudo systemctl start llama-server
    llamaServer = {
      enable = mkEnableOption "llama.cpp Vulkan server (MTP speculative decoding)";

      modelPath = mkOption {
        type = types.str;
        description = "Absolute path to the MTP GGUF model file.";
      };

      draftModelPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to a separate MTP draft head GGUF (Gemma 4 needs this; Qwen has it embedded).";
      };

      alias = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Display name in Open WebUI.";
      };

      port = mkOption {
        type = types.port;
        default = 8001;
        description = "Port for llama-server.";
      };

      contextSize = mkOption {
        type = types.int;
        default = 524288;
        description = "Total context window size. Divided across parallel slots.";
      };

      kvCacheType = mkOption {
        type = types.str;
        default = "q8_0";
        description = "KV cache type (-ctk/-ctv).";
      };
    };
  };

  config = mkIf cfg.enable {
    ollamamodule = mkIf cfg.ollama.enable {
      enable = true;
      acceleration = cfg.acceleration;
      models = cfg.models;
      idleTimeout = cfg.idleTimeout;
      autoStart = cfg.ollama.autoStart;
    };

    openwebuimodule = mkIf cfg.openwebui.enable {
      enable = true;
      port = cfg.openwebui.port;
      corsOrigin = cfg.openwebui.corsOrigin;
      ollamaEnabled = cfg.ollama.enable;
      openaiBaseUrl = mkIf cfg.llamaServer.enable cfg.openwebui.openaiBaseUrl;
    };

    llamaservermodule = mkIf cfg.llamaServer.enable {
      enable = true;
      modelPath = cfg.llamaServer.modelPath;
      draftModelPath = cfg.llamaServer.draftModelPath;
      alias = cfg.llamaServer.alias;
      port = cfg.llamaServer.port;
      contextSize = cfg.llamaServer.contextSize;
      kvCacheType = cfg.llamaServer.kvCacheType;
    };
  };
}