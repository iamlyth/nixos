{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.rustmodule;
in
{
  options.rustmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether or not to enable a system rust configuration";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      cargo
      rustc
    ];
    home.sessionPath = [ "${config.home.homeDirectory}/.cargo/bin" ];
    programs.zsh.initContent = ''
      export PATH="${config.home.homeDirectory}/.cargo/bin:$PATH"
    '';
  };
}
