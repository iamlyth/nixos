# llama.cpp Vulkan server with MTP speculative decoding.
# Runs a single model via systemd. Does not auto-start at boot —
# start manually: sudo systemctl start llama-server
{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.llamaservermodule;
in {
  options.llamaservermodule = {
    enable = mkEnableOption "llama.cpp Vulkan server with MTP speculative decoding";

    package = mkOption {
      type = types.package;
      default = pkgs.llama-cpp-vulkan;
      description = "llama.cpp package (Vulkan build recommended for Strix Halo).";
    };

    modelPath = mkOption {
      type = types.str;
      description = "Absolute path to the main GGUF model file.";
    };

    draftModelPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to a separate MTP draft head GGUF (Gemma 4 needs this; Qwen has it embedded).";
    };

    alias = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Display name for the model (shows in Open WebUI /v1/models).";
    };

    port = mkOption {
      type = types.port;
      default = 8001;
      description = "Port for llama-server.";
    };

    host = mkOption {
      type = types.str;
      default = "0.0.0.0";
      description = "Host address to bind to.";
    };

    user = mkOption {
      type = types.str;
      default = "lalobied";
      description = "User account to run the service as (for GPU access).";
    };

    contextSize = mkOption {
      type = types.int;
      default = 1048576;
      description = "Total context window size. Divided across parallel slots (e.g. 1048576 / 4 slots = 262144 each).";
    };

    specDraftNMax = mkOption {
      type = types.int;
      default = 3;
      description = "Max draft tokens for MTP. Sweet spot is 3.";
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
      description = "Use mmap for model weights.";
    };

    reasoningBudget = mkOption {
      type = types.int;
      default = 4096;
      description = "Token cap for hybrid-thinking reasoning. 0 disables thinking.";
    };

    parallel = mkOption {
      type = types.int;
      default = 4;
      description = "Number of concurrent request slots. Allows pi, Hermes, and Open WebUI to share the model.";
    };

    extraFlags = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Additional flags to pass to llama-server.";
    };

    # ── Qwen3.8-27B (dense, separate MTP draft head) ──────────────
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
      description = "Absolute path to the Qwen3.8-27B main GGUF model file.";
    };

    qwen38DraftModelPath = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Path to the Qwen3.8-27B MTP-only draft head GGUF.";
    };

    qwen38Alias = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Display name for Qwen3.8-27B (shows in Open WebUI /v1/models).";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.llama-server = {
      description = "llama.cpp Vulkan server — MTP speculative decoding (Strix Halo)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      # Manual start only — don't auto-start at boot.
      wantedBy = mkForce [];

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
        "--parallel" (toString cfg.parallel)
      ] ++ (optional cfg.mmap "--load-mode mmap")
        ++ (optionals (cfg.draftModelPath != null) [
          "-md" cfg.draftModelPath
        ])
        ++ (optionals (cfg.alias != null) [
          "--alias" cfg.alias
        ])
        ++ cfg.extraFlags);

      script = ''
        exec ${cfg.package}/bin/llama-server "$@"
      '';

      # Free page cache when the model unloads so the 23GB of mmap'd
      # weights doesn't linger in RAM after stopping the service.
      # The '+' prefix on ExecStopPost tells systemd to run it as root
      # (overrides the User= setting), which is needed for /proc/sys/vm.
      postStop = ''
        true  # cleanup via ExecStopPost below
      '';
    };

    # Single-slot instance: full 262k context, no concurrency.
    # Use when you need maximum context for one long conversation.
    # sudo systemctl start llama-server-single
    # Shares port 8001 with llama-server — mutually exclusive.
    systemd.services.llama-server-single = {
      description = "llama.cpp Vulkan — single slot, full 262k context";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = mkForce [];
      # Prevent concurrent instances — they share port 8001.
      conflicts = [ "llama-server.service" ];
      partOf = [ "llama-server.service" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "video";
        Restart = "on-failure";
        RestartSec = 10;
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
        "--ctx-size" "262144"
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
        "--parallel" "1"
      ] ++ (optional cfg.mmap "--load-mode mmap")
        ++ (optionals (cfg.draftModelPath != null) [
          "-md" cfg.draftModelPath
        ])
        ++ (optionals (cfg.alias != null) [
          "--alias" cfg.alias
        ])
        ++ cfg.extraFlags);

      script = ''
        exec ${cfg.package}/bin/llama-server "$@"
      '';

      postStop = ''
        true  # cleanup via ExecStopPost below
      '';
    };

    # ── Qwen3.8-27B instance ──────────────────────────────────────
    # Dense 28B with separate MTP draft head.
    # sudo systemctl start llama-server-qwen38-27b
    # Runs on its own port (8002) — can coexist with llama-server / -single.
    systemd.services.llama-server-qwen38-27b = mkIf (cfg.qwen38ModelPath != null) {
      description = "llama.cpp Vulkan — Qwen3.8-27B (dense, MTP)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = mkForce [];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "video";
        Restart = "on-failure";
        RestartSec = 10;
        Environment = [
          "GGML_VK_PREFER_HOST_MEMORY=ON"
          "XDG_CACHE_HOME=/var/cache/llama-cpp"
          "MESA_SHADER_CACHE_DIR=/var/cache/llama-cpp"
        ];
        StateDirectory = "llama-cpp";
        CacheDirectory = "llama-cpp";
      };

      scriptArgs = builtins.concatStringsSep " " ([
        "-m" cfg.qwen38ModelPath
        "--spec-type" "draft-mtp"
        "--spec-draft-n-max" (toString cfg.specDraftNMax)
        "-ngl" (toString cfg.gpuLayers)
        "-ngld" (toString cfg.draftGpuLayers)
        "--ctx-size" "262144"
        "--port" (toString cfg.qwen38Port)
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
        "--parallel" "1"
      ] ++ (optional cfg.mmap "--load-mode mmap")
        ++ (optionals (cfg.qwen38DraftModelPath != null) [
          "-md" cfg.qwen38DraftModelPath
        ])
        ++ (optionals (cfg.qwen38Alias != null) [
          "--alias" cfg.qwen38Alias
        ])
        ++ cfg.extraFlags);

      script = ''
        exec ${cfg.package}/bin/llama-server "$@"
      '';

      postStop = ''
        true  # cleanup via ExecStopPost below
      '';
    };

    # Run drop_caches as root for all services
    systemd.services.llama-server.serviceConfig.ExecStopPost = [
      "+${pkgs.bash}/bin/bash -c 'echo 3 > /proc/sys/vm/drop_caches || true'"
    ];
    systemd.services.llama-server-single.serviceConfig.ExecStopPost = [
      "+${pkgs.bash}/bin/bash -c 'echo 3 > /proc/sys/vm/drop_caches || true'"
    ];
    systemd.services.llama-server-qwen38-27b.serviceConfig.ExecStopPost = mkIf (cfg.qwen38ModelPath != null) [
      "+${pkgs.bash}/bin/bash -c 'echo 3 > /proc/sys/vm/drop_caches || true'"
    ];

    networking.firewall.allowedTCPPorts = [ cfg.port ]
      ++ (optional (cfg.qwen38ModelPath != null) cfg.qwen38Port);
  };
}