# Open WebUI frontend. Auto-starts at boot alongside Ollama.
# Also connects to llama-server's OpenAI-compatible API when configured,
# so models from both backends appear in the dropdown simultaneously.
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

    openaiBaseUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "OpenAI-compatible endpoint URL (llama-server). When set, both Ollama and this endpoint appear in the dropdown.";
    };

    ollamaEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable the native Ollama backend. Set false only on hosts with no Ollama.";
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
        ENABLE_OLLAMA_API = "False";
      }) // (optionalAttrs (cfg.openaiBaseUrl != null) {
        # Add llama-server as an OpenAI-compatible backend alongside Ollama.
        OPENAI_API_BASE_URL = cfg.openaiBaseUrl;
        OPENAI_API_BASE_URLS = cfg.openaiBaseUrl;
        OPENAI_API_KEY = "llama-server";
        OPENAI_API_KEYS = "llama-server";
        ENABLE_PERSISTENT_CONFIG = "False";
      });
    };

    systemd.services.open-webui = mkMerge [
      {
        wantedBy = [ "multi-user.target" ];
      }
      (mkIf cfg.ollamaEnabled {
        after = [ "ollama.service" ];
        wants = [ "ollama.service" ];
      })
    ];

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}