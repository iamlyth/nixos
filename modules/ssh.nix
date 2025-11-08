{ pkgs, lib, config, ... }:
with lib; let
  cfg = config.sshmodule;
  defaultPort = 7878;
in{
  options.sshmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Radarr service.
        '';
    };

    port = mkOption {
      type = types.listOf types.ints.u16;
      default = [22];
      example = [22];
      description = ''
        Port for ssh to listen on
        '';
    };
  };

  config = mkIf cfg.enable {
      services.openssh = {
        enable = true;
        ports = cfg.port;
        settings = {
          PasswordAuthentication = true;
          AllowUsers = null;
          UseDns = true;
        };
      };
  }; 
}
