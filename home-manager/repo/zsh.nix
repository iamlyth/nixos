{ pkgs, lib, config, ... }:
with lib; let
	cfg = config.zshmodule;
in{
	options.zshmodule = {
		enable = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable the zsh service.
			'';
		};

		lite = mkOption {
			type = types.bool;
			default = false;
			example = true;
			description = ''
				Whether or not to enable compatibility mode.
			'';
		};
	};
	config = mkIf cfg.enable {
		programs.direnv = {
			enable = true;
			enableZshIntegration = true;
			nix-direnv.enable = true;
		};
		programs.zsh = {
			enable = true;
			autocd = true;
			enableCompletion = true;
			autosuggestion.enable = true;
			syntaxHighlighting.enable = true;
			history.path = "$HOME/.hf";
			history.save = 10000;
			history.size = 10000;
			history.share = true;
			history.extended = true;
			history.ignoreSpace = true;
			oh-my-zsh.enable = true;
			oh-my-zsh.theme = "robbyrussell";
			oh-my-zsh.plugins = [
				"git"
				"history"
				"colored-man-pages"
				"history-substring-search"
				"zsh-interactive-cd"
				"direnv"
				"emoji"
				"eza"
				"fzf" #needed for autosuggestion
			];

			shellAliases = mkIf (cfg.lite == false) {
				ls = "eza";
				ll = "eza --long --git -h";
				pingt = "ping -c 5 google.com";
				gitlog = "git log --graph --abbrev-commit --decorate
				--date=format:'(%m_%d)' --format=format:'%C(bold blue)%h%C(reset) %C(bold
				green)%ad%C(reset) %C(white)- %an%C(reset)%C(auto)%d%C(reset)'";
			};

			sessionVariables = {
				EDITOR = "vim";
			};
		};
	};
}
