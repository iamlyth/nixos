{
  description = "A template that shows all standard flake outputs";

  # Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.3";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    # Old ollama rev for temporary rollback while gemma4/pi /v1 issue
    # is sorted upstream. See ollama/ollama#15288.
    nixpkgs-ollama.url = "github:nixos/nixpkgs/4100e830e085863741bc69b156ec4ccd53ab5be0";
    # claude-code 2.1.170 from nixpkgs PR #530023, pending merge to unstable/26.11.
    nixpkgs-claude-pr.url = "github:nixos/nixpkgs/5900fe6cf8eca7dc124309029a50c7f80e90b6c9";
    pi-nix.url = "github:lukasl-dev/pi.nix";
    jaildotnix.url = "sourcehut:~alexdavid/jail.nix";
    jetpack.url = "github:anduril/jetpack-nixos/master";
    jetpack.inputs.nixpkgs.follows = "nixpkgs";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
       inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager-unstable = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-hardware, nixos-generators, ... }@inputs:
  let
    system = "x86_64-linux";
    mkSystem = import ./lib/mkSystem.nix { inherit inputs system; };
    # Stable package set, passed via specialArgs to unstable hosts that
    # still need an occasional stable package (e.g. VLC with BD+ support).
    stablenix = import nixpkgs { inherit system; };
  in
  {
    nixosConfigurations = {
      mediaOS = mkSystem {
        hostModule = ./hosts/mediaOS.nix;
        homeProfile = ./home-manager/server-home.nix;
        homeStateVersion = "25.05";
        extraModules = [ inputs.vpn-confinement.nixosModules.default ];
      };

      desktopOS = mkSystem {
        unstable = true;
        hostModule = ./hosts/desktopOS.nix;
        homeProfile = ./home-manager/desktop-home.nix;
        homeExtraModules = [ inputs.nixvim.homeModules.nixvim ];
        specialArgs = { inherit stablenix; };
        extraModules = [
          nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
      };

      laptopOS = mkSystem {
        unstable = true;
        hostModule = ./hosts/laptopOS.nix;
        homeProfile = ./home-manager/laptop-home.nix;
        homeExtraModules = [ inputs.nixvim.homeModules.nixvim ];
        specialArgs = { inherit stablenix; };
        extraModules = [
          nixos-hardware.nixosModules.framework-12-13th-gen-intel
          inputs.lanzaboote.nixosModules.lanzaboote
        ];
      };

      tatchiOS = mkSystem {
        hostModule = ./hosts/tatchiOS.nix;
        homeProfile = ./home-manager/server-home.nix;
        homeStateVersion = "25.11";
        extraModules = [ inputs.jetpack.nixosModules.default ];
      };

      wsl = mkSystem {
        hostModule = ./hosts/wsl.nix;
        homeProfile = ./home-manager/portable-home.nix;
        homeExtraModules = [ inputs.nixvim.homeModules.nixvim ];
        extraModules = [ inputs.nixos-wsl.nixosModules.wsl ];
      };

      paperLXC = mkSystem {
        hostModule = ./hosts/paperLXC.nix;
        homeProfile = ./home-manager/server-home.nix;
        homeStateVersion = "25.11";
      };

      photoLXC = mkSystem {
        hostModule = ./hosts/photoLXC.nix;
        homeProfile = ./home-manager/server-home.nix;
        homeStateVersion = "25.11";
      };

      pijukeboxOS = mkSystem {
        system = "aarch64-linux";
        hostModule = ./hosts/pijukeboxOS.nix;
        homeProfile = ./home-manager/server-home.nix;
        homeStateVersion = "26.05";
        extraModules = [ nixos-hardware.nixosModules.raspberry-pi-4 ];
      };
    };

    packages.${system} =
      let
        nvim = inputs.nixvim.legacyPackages.${system}.makeNixvim
          (import ./config/nvim.nix);
      in
      {
        # Proxmox LXC template
        lxctemplate = nixos-generators.nixosGenerate {
          inherit system;
          modules = [
            ./templates/lxctemplate.nix
          ];
          format = "proxmox-lxc";
        };

        # Standalone nvim, built from the same config home-manager uses.
        # `nix run .#nvim` or `nix build .#nvim`.
        inherit nvim;
      };

    # Bootable SD card image for a Raspberry Pi 4. Build with
    # `nix build .#piImage` from an aarch64 host, or from x86_64 after
    # adding `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` to
    # one of the existing hosts.
    packages.aarch64-linux.piImage = nixos-generators.nixosGenerate {
      system = "aarch64-linux";
      modules = [
        ./templates/pitemplate.nix
        nixos-hardware.nixosModules.raspberry-pi-4
      ];
      format = "sd-aarch64";
    };
  };
}
