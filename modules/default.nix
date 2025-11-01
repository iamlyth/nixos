{pkgs, lib, config, ...}:
with lib; let
  cfg = config.media;
  mediavalues = config.media.globals;
  defaultMediaDir = "/media/";
in{
  imports = [
    ./plex.nix
    ./radarr.nix
    ./ssh.nix
  ];
  options.media = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Radarr service.
        '';
    };

    mediaUsers = mkOption {
      type = with types; listOf str;
      default = [];
      example = ["user"];
      description = ''
        extra users to add to media group.
      '';
    };

    mediaDir = mkOption {
      type = types.path;
      default = "/media/";
      example = "/data/media";
      description = ''
        where all the good stuff lives
      '';
    };

    mediavalues.globals = mkOption {
      type = types.attrs;
      default ={};
      description = "media specific stuff";
    };
  };
  config = mkIf cfg.enable {
    media.mediavalues.globals = {
      libraryOwner.group = "media";
     };
  };
}
