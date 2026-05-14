{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.aimodule;
in{
  options.aimodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable ai.
        '';
    };
  };

  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-rocm;
      loadModels = [ "gemma4:26b" ];
      host = "0.0.0.0";
      environmentVariables = {
        HSA_OVERRIDE_GFX_VERSION = "11.0.0";
      };
    };
    systemd.services.ollama = {
      wantedBy = lib.mkForce [];
      serviceConfig = {
        TimeoutIdleSec = "5min"; #stop if idle
      };
    };
    networking.firewall.allowedTCPPorts = [ 8080 11434 ];
    services.open-webui = {
      enable = true;
      port = 8080;
      host = "0.0.0.0";
      environment = {
        CORS_ALLOW_ORIGIN = "https://ai.tatchi.org";
      };
    };
    systemd.services.open-webui = {
      wantedBy = lib.mkForce [];
      after = [ "ollama.service" ];
      requires = [ "ollama.service" ];
    };
  };
}
