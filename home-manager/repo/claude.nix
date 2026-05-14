{ pkgs, lib, config, ... }:
with lib; let
	cfg = config.claudemodule;
	claudePluginsOfficial = pkgs.fetchFromGitHub {
		owner = "anthropics";
		repo = "claude-plugins-official";
		rev = "0742692199b49af5c6c33cd68ee674fb2e679d50";
		hash = "sha256-5h7uXbqtuguCw9AMpEFJiKAH7ZmGgJJvm3yyec6+BXE=";
	};
	claudeSkills = pkgs.fetchFromGitHub {
		owner = "anthropics";
		repo = "skills";
		rev = "f458cee31a7577a47ba0c9a101976fa599385174";
		hash = "sha256-jKNYFom6R+Qw7LQ8vFPBe51JpqIP0tTSY8LM4aPlnT4=";
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
		home.sessionVariables = {
			CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS = "1";
		};
		home.file.".claude/skills/skill-creator" = {
			source = "${claudePluginsOfficial}/plugins/skill-creator/skills/skill-creator";
			recursive = true;
		};
		home.file.".claude/skills/docx" = {
			source = "${claudeSkills}/skills/docx";
			recursive = true;
		};
		home.file.".claude/skills/pdf" = {
			source = "${claudeSkills}/skills/pdf";
			recursive = true;
		};
		home.file.".claude/skills/xlsx" = {
			source = "${claudeSkills}/skills/xlsx";
			recursive = true;
		};
		home.file.".claude/skills/pptx" = {
			source = "${claudeSkills}/skills/pptx";
			recursive = true;
		};
	};
}
