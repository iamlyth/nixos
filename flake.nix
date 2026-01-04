{
  description = "A template that shows all standard flake outputs";

  # Inputs
  inputs = {
		nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
		vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
		nixos-hardware.url = "github:NixOS/nixos-hardware/master";
		lanzaboote.url = "github:nix-community/lanzaboote/v0.4.3";
		darwin.url = "github:lnl7/nix-darwin/nix-darwin-25.11";
		darwin.inputs.nixpkgs.follows = "nixpkgs";
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
  };
  outputs = {self, nixpkgs, vpn-confinement, nixos-hardware, lanzaboote,
home-manager, nixos-generators,  ...
  }@inputs: {
		nixosConfigurations = {
			mOS = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = import ./home-manager/server-home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./hosts/mOS.nix
          vpn-confinement.nixosModules.default
        ];
      };

      dOS = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = import ./home-manager/desktop-home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./hosts/dOS.nix
        ];
      };

      tOS = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
					nixos-hardware.nixosModules.framework-desktop-amd-ai-max-300-series
					lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = import ./home-manager/desktop-home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./hosts/tOS.nix
        ];
      };
      cOS = let system = "x86_64-linux";
      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = import ./home-manager/server-home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./hosts/cOS.nix
        ];
      };
    };
    darwinConfigurations."lythbook3" = inputs.darwin.lib.darwinSystem {
        system = "x86_64-darwin";
        modules = [
          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
							imports = [
								./home-manager/portable-home.nix
								inputs.nixvim.homeManagerModules.nixvim
							];
						};
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
	  			./hosts/aOS.nix
        ];
    };
		packages.x86_64-linux = {
			photoOS = nixos-generators.nixosGenerate {
				system = "x86_64-linux";
				modules = [
					home-manager.darwinModules.home-manager
					{
						home-manager.useGlobalPkgs = true;
						home-manager.useUserPackages = true;
						home-manager.users.lalobied = import ./home-manager/server-home.nix;
						home-manager.extraSpecialArgs = {
							inherit inputs;
						};
					}
					./containers/photoOS.nix
				];
				format = "proxmox-lxc";
			};
		};
  };
}
