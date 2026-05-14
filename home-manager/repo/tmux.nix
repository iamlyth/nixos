{pkgs, lib, inputs, config, ... }:
with lib; let
  cfg = config.tmuxmodule;
in{
  options.tmuxmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable tmux
      '';
    };
  };
  config = mkIf cfg.enable {
    programs.tmux = {
      enable = true;
      mouse = true;
    };
  };
}
