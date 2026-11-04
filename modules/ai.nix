# AI services module. Coordinates Ollama, Open WebUI, and llama-server.
#
# Desktop: Ollama + Open WebUI auto-start at boot. llama-server starts
#   manually for MTP 81 t/s inference. Open WebUI connects to both.
# Tatchi: llama-server (CUDA) auto-starts at boot with the fine-tuned HA
#   model. Ollama disabled to maximize memory headroom on 8GB Jetson.
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

    # llama.cpp server with Vulkan (desktop) or CUDA (Jetson) backend.
    # Supports MTP speculative decoding and hybrid-thinking reasoning.
    llamaServer = {
      enable = mkEnableOption "llama.cpp server (Vulkan or CUDA backend)";

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
        default = 1048576;
        description = "Total context window size. Divided across parallel slots.";
      };

      kvCacheType = mkOption {
        type = types.str;
        default = "q8_0";
        description = "KV cache type (-ctk/-ctv).";
      };

      acceleration = mkOption {
        type = types.enum [ "vulkan" "cuda" ];
        default = "vulkan";
        description = "GPU acceleration backend for llama-server.";
      };

      enableSpeculative = mkOption {
        type = types.bool;
        default = true;
        description = "Enable speculative decoding (MTP or DFlash). Disable on memory-constrained devices.";
      };

      specType = mkOption {
        type = types.enum [ "draft-mtp" "draft-dflash" ];
        default = "draft-mtp";
        description = "Speculative decoding type. Use draft-dflash for NVIDIA DFlash drafter.";
      };

      specDraftNMax = mkOption {
        type = types.int;
        default = 3;
        description = "Max draft tokens for speculative decoding. NVIDIA recommends 7 for DFlash.";
      };

      enableReasoning = mkOption {
        type = types.bool;
        default = true;
        description = "Enable hybrid-thinking reasoning. Disable on memory-constrained devices.";
      };

      autoStart = mkOption {
        type = types.bool;
        default = false;
        description = "Auto-start llama-server at boot.";
      };

      parallel = mkOption {
        type = types.int;
        default = 4;
        description = "Number of concurrent request slots.";
      };

      ubatchSize = mkOption {
        type = types.int;
        default = 1024;
        description = "Micro-batch size for prompt processing.";
      };

      gpuLayers = mkOption {
        type = types.int;
        default = 99;
        description = "Number of layers to offload to GPU (-ngl).";
      };

      flashAttention = mkOption {
        type = types.bool;
        default = true;
        description = "Enable flash attention (-fa 1).";
      };

      mmap = mkOption {
        type = types.bool;
        default = true;
        description = "Use mmap for model weights.";
      };

      reasoningBudget = mkOption {
        type = types.int;
        default = 4096;
        description = "Token cap for hybrid-thinking reasoning. 0 disables thinking.";
      };

      user = mkOption {
        type = types.str;
        default = "lalobied";
        description = "User account to run the service as (for GPU access).";
      };

      extraFlags = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional flags to pass to llama-server.";
      };

      # Qwen3.8-27B alternate model (dense, separate MTP draft head).
      # sudo systemctl start llama-server-qwen38-27b
      # Runs on its own port (8002) — can coexist with llama-server / -single.
      qwen38Port = mkOption {
        type = types.port;
        default = 8002;
        description = "Port for the Qwen3.8-27B llama-server instance.";
      };

      qwen38ModelPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to the Qwen3.8-27B main GGUF. Null disables the unit.";
      };

      qwen38DraftModelPath = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Path to the Qwen3.8-27B MTP-only draft head GGUF.";
      };

      qwen38Alias = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Display name for Qwen3.8-27B in Open WebUI.";
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
      acceleration = cfg.llamaServer.acceleration;
      enableSpeculative = cfg.llamaServer.enableSpeculative;
      specType = cfg.llamaServer.specType;
      specDraftNMax = cfg.llamaServer.specDraftNMax;
      enableReasoning = cfg.llamaServer.enableReasoning;
      autoStart = cfg.llamaServer.autoStart;
      modelPath = cfg.llamaServer.modelPath;
      draftModelPath = cfg.llamaServer.draftModelPath;
      alias = cfg.llamaServer.alias;
      port = cfg.llamaServer.port;
      contextSize = cfg.llamaServer.contextSize;
      kvCacheType = cfg.llamaServer.kvCacheType;
      parallel = cfg.llamaServer.parallel;
      ubatchSize = cfg.llamaServer.ubatchSize;
      gpuLayers = cfg.llamaServer.gpuLayers;
      flashAttention = cfg.llamaServer.flashAttention;
      mmap = cfg.llamaServer.mmap;
      reasoningBudget = cfg.llamaServer.reasoningBudget;
      user = cfg.llamaServer.user;
      extraFlags = cfg.llamaServer.extraFlags;
      qwen38ModelPath = cfg.llamaServer.qwen38ModelPath;
      qwen38DraftModelPath = cfg.llamaServer.qwen38DraftModelPath;
      qwen38Alias = cfg.llamaServer.qwen38Alias;
      qwen38Port = cfg.llamaServer.qwen38Port;
    };
  };
}