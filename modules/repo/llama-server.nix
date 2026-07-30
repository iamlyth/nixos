{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.llamaservermodule;
in {
  options.llamaservermodule = {
    enable = mkEnableOption "llama.cpp Vulkan server with MTP speculative decoding";

    package = mkOption {
      type = types.package;
      default = pkgs.llama-cpp-vulkan;
      description = "llama.cpp package to use (Vulkan build recommended for Strix Halo).";
    };

    modelPath = mkOption {
      type = types.str;
      description = "Absolute path to the main GGUF model file.";
    };

    draftModelPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to a separate MTP draft model GGUF (if not using native grafted MTP).";
    };

    port = mkOption {
      type = types.port;
      default = 8001;
      description = "Port for llama-server to listen on.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host address to bind to.";
    };

    contextSize = mkOption {
      type = types.int;
      default = 262144;
      description = "Context window size (Qwen3.6 supports 256k).";
    };

    specDraftNMax = mkOption {
      type = types.int;
      default = 3;
      description = "Max draft tokens for MTP. Sweet spot is 3; higher lowers acceptance.";
    };

    gpuLayers = mkOption {
      type = types.int;
      default = 99;
      description = "Number of layers to offload to GPU (-ngl).";
    };

    draftGpuLayers = mkOption {
      type = types.int;
      default = 99;
      description = "Number of draft model layers to offload (-ngld).";
    };

    kvCacheType = mkOption {
      type = types.str;
      default = "q8_0";
      description = "KV cache type for both key and value (-ctk/-ctv).";
    };

    ubatchSize = mkOption {
      type = types.int;
      default = 1024;
      description = "Micro-batch size for prompt processing. 1024 is the Strix Halo sweet spot.";
    };

    flashAttention = mkOption {
      type = types.bool;
      default = true;
      description = "Enable flash attention (-fa 1). Required for good Strix Halo performance.";
    };

    mmap = mkOption {
      type = types.bool;
      default = true;
      description = "Use mmap for model weights. Fine under the GTT regime with 1GB VGM carve.";
    };

    reasoningBudget = mkOption {
      type = types.int;
      default = 4096;
      description = "Token cap for hybrid-thinking reasoning. 0 disables thinking.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional flags to pass to llama-server.";
    };

    user = mkOption {
      type = types.str;
      default = "lalobied";
      description = "User account to run the service as (for GPU access).";
    };
  };

  config = mkIf cfg.enable {
    # Provide the llama.cpp binaries in system packages for manual use
    environment.systemPackages = [ cfg.package ];

    systemd.services.llama-server = {
      description = "llama.cpp Vulkan server — MTP speculative decoding (Strix Halo)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "video";
        Restart = "on-failure";
        RestartSec = 10;
        # Shader cache fix (nixpkgs#441531)
        Environment = [
          "GGML_VK_PREFER_HOST_MEMORY=ON"
          "XDG_CACHE_HOME=/var/cache/llama-cpp"
          "MESA_SHADER_CACHE_DIR=/var/cache/llama-cpp"
        ];
        StateDirectory = "llama-cpp";
        CacheDirectory = "llama-cpp";
      };

      scriptArgs = builtins.concatStringsSep " " ([
        "-m" cfg.modelPath
        "--spec-type" "draft-mtp"
        "--spec-draft-n-max" (toString cfg.specDraftNMax)
        "-ngl" (toString cfg.gpuLayers)
        "-ngld" (toString cfg.draftGpuLayers)
        "--ctx-size" (toString cfg.contextSize)
        "--port" (toString cfg.port)
        "--host" cfg.host
        "--no-warmup"
        "--jinja"
        "--ubatch-size" (toString cfg.ubatchSize)
        "-fa" (if cfg.flashAttention then "1" else "0")
        "-ctk" cfg.kvCacheType
        "-ctv" cfg.kvCacheType
        "--cache-prompt"
        "--reasoning-budget" (toString cfg.reasoningBudget)
        "--reasoning-format" "auto"
      ] ++ (optional cfg.mmap "--mmap")
        ++ (optionals (cfg.draftModelPath != null) [
          "-md" cfg.draftModelPath
        ])
        ++ cfg.extraFlags);

      script = ''
        exec ${cfg.package}/bin/llama-server "$@"
      '';
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}