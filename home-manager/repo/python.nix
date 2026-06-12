{ lib, config, pkgs, ... }:
with lib;
let
  cfg = config.pythonmodule;
in
{
  options.pythonmodule = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether or not to enable a system python configuration";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      (python312.withPackages (ps: with ps; [
        requests
        numpy
        httpx
        markitdown
      ]))
      uv
    ];
    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    programs.zsh.initContent = ''
      export PATH="${config.home.homeDirectory}/.local/bin:$PATH"
    '';
  };
}
