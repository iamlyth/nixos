{ pkgs, lib, config, ... }:
with lib; let
	cfg = config.claudemodule;
	claudePluginsOfficial = pkgs.fetchFromGitHub {
		owner = "anthropics";
		repo = "claude-plugins-official";
		rev = "0742692199b49af5c6c33cd68ee674fb2e679d50";
		hash = "sha256-5h7uXbqtuguCw9AMpEFJiKAH7ZmGgJJvm3yyec6+BXE=";
	};
in{
	options.claudemodule = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable claude.
			'';
		};
	};
	config = mkIf cfg.enable {
		programs.claude-code.enable = true;
		home.file.".claude/skills/skill-creator" = {
			source = "${claudePluginsOfficial}/plugins/skill-creator/skills/skill-creator";
			recursive = true;
		};
	};
}
