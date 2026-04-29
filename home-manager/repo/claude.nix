{ pkgs, lib, config, ... }:
with lib; let
	cfg = config.claudemodule;
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
		programs.claude-code = {
			enable = true;
			settings = {
				# Plugin configuration
				# Register the official Anthropic plugin marketplace
				extraKnownMarketplaces = {
					claude-code-plugins = {
						source = {
							source = "github";
							repo = "anthropics/claude-code";
						};
					};
					claude-plugins-official = {
						source = {
							source = "github";
							repo = "anthropics/claude-plugins-official";
						};
					};
				};
			};
		};
	};
}
