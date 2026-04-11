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

  outputs = {self, nixpkgs, nixos-hardware, home-manager, nixos-generators, ... }@inputs: 
	{
		nixosConfigurations = {
			### Define mediaOS	
			mediaOS = let system = "x86_64-linux";
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
          ./hosts/mediaOS.nix
          inputs.vpn-confinement.nixosModules.default
        ];
      };

			### Define desktopOS
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
					{ nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.default ]; }
					inputs.lanzaboote.nixosModules.lanzaboote
          inputs.home-manager-unstable.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
							imports = [
								./home-manager/desktop-home.nix
								inputs.nixvim.homeManagerModules.nixvim
							];
						};
						home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./hosts/desktopOS.nix
        ];
      };

			### Define laptopOS
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
								inputs.nixvim.homeManagerModules.nixvim
							];
						};
						home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./hosts/laptopOS.nix
        ];
      };
		
			### Define NixOS-WSL
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
								inputs.nixvim.homeManagerModules.nixvim
							];
						};
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ./hosts/wsl.nix
				];
			};

			### Define paperLXC	
			paperLXC = let system = "x86_64-linux";
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
          ./containers/paperLXC.nix
        ];
      };

			### Define photoLXC	
			photoLXC = let system = "x86_64-linux";
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
          ./containers/photoLXC.nix
        ];
      };
    };
		
		#LXC Container Template
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
