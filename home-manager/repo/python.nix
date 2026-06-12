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
    extras = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to include heavy ML/inference packages (e.g. markitdown with onnxruntime)";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      (python312.withPackages (ps: with ps; [
        requests
        numpy
        httpx
      ] ++ lib.optionals cfg.extras [
        ps.markitdown
      ]))
      uv
    ];
    home.sessionPath = [ "${config.home.homeDirectory}/.local/bin" ];
    programs.zsh.initContent = ''
      export PATH="${config.home.homeDirectory}/.local/bin:$PATH"
    '';
  };
}
