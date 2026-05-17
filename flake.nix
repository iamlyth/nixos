{
  description = "A template that shows all standard flake outputs";

  # Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.3";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    pi-nix.url = "github:lukasl-dev/pi.nix";
    jaildotnix.url = "sourcehut:~alexdavid/jail.nix";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
       inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
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
    mkSystem = import ./lib/mkSystem.nix { inherit inputs; };
    # Stable package set, passed via specialArgs to unstable hosts that
    # still need an occasional stable package (e.g. VLC with BD+ support).
    stablenix = import nixpkgs { inherit system; };
  in
  {
    nixosConfigurations = {
      mediaOS = mkSystem {
        hostModule = ./hosts/mediaOS.nix;
        homeProfile = ./home-manager/server-home.nix;
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
          {
            nixpkgs.overlays = [
              inputs.nix-cachyos-kernel.overlays.default
              # Skipping tests while upstream sorts it out, revert once
              # Hydra consistently builds openldap green.
              (_: prev: {
                openldap = prev.openldap.overrideAttrs (_: {
                  doCheck = false;
                });
              })
            ];
          }
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

      wsl = mkSystem {
        hostModule = ./hosts/wsl.nix;
        homeProfile = ./home-manager/portable-home.nix;
        homeExtraModules = [ inputs.nixvim.homeModules.nixvim ];
        extraModules = [ inputs.nixos-wsl.nixosModules.wsl ];
      };

      paperLXC = mkSystem {
        hostModule = ./containers/paperLXC.nix;
        homeProfile = ./home-manager/server-home.nix;
      };

      photoLXC = mkSystem {
        hostModule = ./containers/photoLXC.nix;
        homeProfile = ./home-manager/server-home.nix;
      };
    };

    # LXC Container Template
    packages.${system} = {
      lxctemplate = nixos-generators.nixosGenerate {
        inherit system;
        modules = [
          ./containers/lxctemplate.nix
        ];
        format = "proxmox-lxc";
      };
    };
  };
}
