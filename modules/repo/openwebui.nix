{ lib, config, ... }:
with lib; let
  cfg = config.openwebuimodule;
in {
  options.openwebuimodule = {
    enable = mkEnableOption "Open WebUI frontend for AI chat";

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port to listen on.";
    };

    corsOrigin = mkOption {
      type = types.str;
      default = "*";
      example = "https://ai.example.com";
      description = "Value for CORS_ALLOW_ORIGIN.";
    };

    # When Ollama is disabled, Open WebUI connects to llama-server (or any
    # OpenAI-compatible endpoint) via OPENAI_API_BASE_URL instead of the
    # native Ollama API.
    openaiBaseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "OpenAI-compatible endpoint URL. Set when not using Ollama.";
    };

    ollamaEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Whether Ollama is running on this host. Controls service dependencies and backend config.";
    };
  };

  config = mkIf cfg.enable {
    services.open-webui = {
      enable = true;
      port = cfg.port;
      host = "0.0.0.0";
      environment = {
        CORS_ALLOW_ORIGIN = cfg.corsOrigin;
      } // (optionalAttrs (!cfg.ollamaEnabled) {
        # Point Open WebUI at the llama-server OpenAI-compatible endpoint
        # and disable the Ollama backend so it doesn't try to reach :11434.
        OPENAI_API_BASE_URL = cfg.openaiBaseUrl;
        OPENAI_API_KEY = "llama-server";
        ENABLE_OLLAMA_API = "False";
        # Persist config from env vars on every restart (see open-webui docs
        # on ConfigVar behavior — without this, first-boot values stick and
        # later env changes are ignored).
        ENABLE_PERSISTENT_CONFIG = "False";
      });
    };

    systemd.services.open-webui = {
      after = if cfg.ollamaEnabled then [ "ollama.service" ] else [ "llama-server.service" ];
      requires = if cfg.ollamaEnabled then [ "ollama.service" ] else [ "llama-server.service" ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}