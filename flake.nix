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

  outputs = {self, nixpkgs, nixos-hardware, home-manager, nixos-generators, ... }@inputs: 
  {
    nixosConfigurations = {
      # Define mediaOS  
      mediaOS = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [ ./home-manager/server-home.nix ];
              home.stateVersion = "25.05";
            };
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./hosts/mediaOS.nix
          inputs.vpn-confinement.nixosModules.default
        ];
      };

      # Define desktopOS
      desktopOS = let system = "x86_64-linux";
      in inputs.nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          stablenix = import nixpkgs {
            inherit system;
          };
        };
        modules = [
          nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
          { nixpkgs.overlays = [
            inputs.nix-cachyos-kernel.overlays.default
            # Skipping tests while upstream sorts it out, revert once
            # Hydra consistently builds openldap green.
            (_: prev: {
              openldap = prev.openldap.overrideAttrs (_: {
                doCheck = false;
              });
            })
            # Temporarily pull ollama-rocm from an older nixpkgs while the
            # current ollama's reasoning_content streaming breaks pi on /v1.
            (_: _: {
              ollama-rocm = (import inputs.nixpkgs-ollama {
                inherit system;
                config.allowUnfree = true;
              }).ollama-rocm;
            })
          ]; }
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.home-manager-unstable.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [
                ./home-manager/desktop-home.nix
                inputs.nixvim.homeModules.nixvim
              ];
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./hosts/desktopOS.nix
        ];
      };

      # Define laptopOS
      laptopOS = let system = "x86_64-linux";
      in inputs.nixpkgs-unstable.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          stablenix = import nixpkgs {
            inherit system;
          };
        };
        modules = [
          nixos-hardware.nixosModules.framework-12-13th-gen-intel
          inputs.lanzaboote.nixosModules.lanzaboote
          inputs.home-manager-unstable.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [
                ./home-manager/laptop-home.nix
                inputs.nixvim.homeModules.nixvim
              ];
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./hosts/laptopOS.nix
        ];
      };
    
      # Define NixOS-WSL
      wsl = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          inputs.nixos-wsl.nixosModules.wsl
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [
                ./home-manager/portable-home.nix
                inputs.nixvim.homeModules.nixvim
              ];
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./hosts/wsl.nix
        ];
      };
     
      # Define TatchiOS 
      tatchiOS = let system = "aarch64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [ ./home-manager/server-home.nix ];
              home.stateVersion = "25.11";
            };
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
	  inputs.jetpack.nixosModules.default
          ./hosts/tatchiOS.nix
        ];
      };

      # Define paperLXC  
      paperLXC = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [ ./home-manager/server-home.nix ];
              home.stateVersion = "25.11";
            };
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./containers/paperLXC.nix
        ];
      };

      # Define photoLXC  
      photoLXC = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [ ./home-manager/server-home.nix ];
              home.stateVersion = "25.11";
            };
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./containers/photoLXC.nix
        ];
      };
    };
    
    # LXC Container Template
    packages.x86_64-linux = {
      lxctemplate = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        modules = [
          ./containers/lxctemplate.nix
        ];
        format = "proxmox-lxc";
      };
    };
  };
}
