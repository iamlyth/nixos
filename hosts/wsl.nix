{ config, lib, pkgs, ... }:

{
	imports = [
		#<nixos-wsl/modules>
	];
	wsl.enable = true;
	wsl.defaultUser = "lalobied";

	nix.settings.experimental-features = ["nix-command" "flakes"];

	### SHELL
	programs.zsh.enable = true;
	users.defaultUserShell = pkgs.zsh;

	environment.systemPackages = with pkgs; [
		git
		tmux
		eza
		fzf #needed for zsh auto suggestion
	];

	#timezone
  time.timeZone = "US/Michigan";

	#where was I and what am I made of?	
	nixpkgs.hostPlatform = "x86_64-linux";
	system.stateVersion = "25.11";
}
