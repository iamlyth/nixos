{ lib, config, ... }:
with lib; let
  cfg = config.openwebuimodule;
in {
  options.openwebuimodule = {
    enable = mkEnableOption "Open WebUI frontend for ollama";

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
  };

  config = mkIf cfg.enable {
    services.open-webui = {
      enable = true;
      port = cfg.port;
      host = "0.0.0.0";
      environment = {
        CORS_ALLOW_ORIGIN = cfg.corsOrigin;
      };
    };

    systemd.services.open-webui = {
      wantedBy = mkForce [];
      after = [ "ollama.service" ];
      requires = [ "ollama.service" ];
    };

    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
