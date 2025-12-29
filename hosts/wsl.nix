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
		eza
		fzf #needed for zsh auto suggestion
	];
	nixpkgs.hostPlatform = "x86_64-linux";
	system.stateVersion = "25.11";

}
