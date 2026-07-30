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
      description = "GPU acceleration backend for ollama. Only used when ollama.enable = true.";
    };

    # Ollama is optional — desktop uses llama-server only, tatchi uses Ollama.
    ollama.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable Ollama LLM server. Disable on hosts using llama-server exclusively.";
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

      # When Ollama is disabled, Open WebUI connects to llama-server via
      # its OpenAI-compatible API instead of the native Ollama API.
      openaiBaseUrl = mkOption {
        type = types.str;
        default = "http://localhost:8001/v1";
        description = "OpenAI-compatible endpoint for Open WebUI (used when ollama.enable = false).";
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
    ollamamodule = mkIf cfg.ollama.enable {
      enable = true;
      acceleration = cfg.acceleration;
      models = cfg.models;
      idleTimeout = cfg.idleTimeout;
    };

    openwebuimodule = mkIf cfg.openwebui.enable {
      enable = true;
      port = cfg.openwebui.port;
      corsOrigin = cfg.openwebui.corsOrigin;
      # When Ollama is off, pass llama-server as the OpenAI endpoint and
      # disable the Ollama backend so Open WebUI doesn't try to reach it.
      openaiBaseUrl = mkIf (!cfg.ollama.enable) cfg.openwebui.openaiBaseUrl;
      ollamaEnabled = cfg.ollama.enable;
    };

    llamaservermodule = mkIf cfg.llamaServer.enable {
      enable = true;
      modelPath = cfg.llamaServer.modelPath;
      port = cfg.llamaServer.port;
      contextSize = cfg.llamaServer.contextSize;
    };
  };
}
