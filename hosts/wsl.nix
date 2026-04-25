{ config, lib, pkgs, ... }:

{
	imports = [
		#<nixos-wsl/modules>
	];
	wsl.enable = true;
	wsl.defaultUser = "lalobied";
	wsl.wslConf = {
		automount.enabled = lib.mkForce true;
	};

	nix.settings.experimental-features = ["nix-command" "flakes"];


  nixpkgs.config.allowUnfree = true; #allow proprietary packages

	### SHELL
	programs.zsh.enable = true;
	users.defaultUserShell = pkgs.zsh;

	environment.systemPackages = with pkgs; [
		git
		tmux
		eza
		fzf #needed for zsh auto suggestion
		ripgrep
		claude-code
	];

	#timezone
  time.timeZone = "US/Michigan";

	#where was I and what am I made of?	
	nixpkgs.hostPlatform = "x86_64-linux";
	system.stateVersion = "25.11";
}
