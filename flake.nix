{
  description = "A template that shows all standard flake outputs";

  # Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
		nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {self, nixpkgs, vpn-confinement, nixos-hardware, home-manager, ...
  }@inputs: {
    nixosConfigurations = {
      mOS = let
        system = "x86_64-linux";

      in nixpkgs.lib.nixosSystem {
        modules = [
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = import ./home-manager/home.nix;
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
            home-manager.users.lalobied = import ./home-manager/homedesktop.nix;
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
          home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = import ./home-manager/homedesktop.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
            };
          }
          ./hosts/tOS.nix
        ];
      };

	  
    };
  };
}
