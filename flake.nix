{
  description = "A template that shows all standard flake outputs";

  # Binary cache for the Pi flake — prebuilt linux_rpi4 kernels live here.
  # Massive build-time saver vs. compiling on x86_64 via binfmt.
  nixConfig = {
    extra-substituters = [
      "https://nixos-raspberrypi.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  # Inputs
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    nix-cachyos-kernel.url = "github:xddxdd/nix-cachyos-kernel/release";
    # Old ollama rev for temporary rollback while gemma4/pi /v1 issue
    # is sorted upstream. Added 2026-06-08.
    # Checked 2026-07-08: still needed. ollama/ollama#15288 was closed as
    # a misdiagnosis; the real tracker is ollama/ollama#10976 (thinking
    # forced on for /v1 tool requests), fix pending in ollama/ollama#16758.
    nixpkgs-ollama.url = "github:nixos/nixpkgs/4100e830e085863741bc69b156ec4ccd53ab5be0";
    pi-nix.url = "github:lukasl-dev/pi.nix";
    jaildotnix.url = "sourcehut:~alexdavid/jail.nix";
    jetpack.url = "github:anduril/jetpack-nixos/master";
    jetpack.inputs.nixpkgs.follows = "nixpkgs";
    # nvmd's flake — actively-maintained Pi support that ships its own
    # working raspberry-pi-4.{base,bluetooth} modules built on top of
    # the vendor (RPi-Trading) kernel + DTBs. Replaces our previous
    # nixos-hardware + raspberry-pi-nix experiments.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
       inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim = {
      url = "github:nix-community/nixvim/nixos-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixvim-unstable = {
      url = "github:nix-community/nixvim/main";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
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

  outputs = { self, nixpkgs, nixos-hardware, nixos-generators, nixos-raspberrypi, ... }@inputs:
  let
    system = "x86_64-linux";
    mkSystem = import ./lib/mkSystem.nix { inherit inputs system; };
    # Stable package set, passed via specialArgs to unstable hosts that
    # still need an occasional stable package (e.g. VLC with BD+ support).
    stablenix = import nixpkgs { inherit system; };

    # Helper for Pi configurations. Uses nixos-raspberrypi.lib.nixosSystem
    # (a drop-in replacement for nixpkgs.lib.nixosSystem) which wires up
    # the vendor kernel + firmware + cachix-trusted overlays for us.
    # Wires home-manager in by hand because we're bypassing mkSystem.
    mkPiSystem = piModules: hostModule:
      nixos-raspberrypi.lib.nixosSystem {
        # Pin to our nixpkgs (26.05) instead of the 25.11 bundled with
        # nixos-raspberrypi, so home-manager-26.05 stays compatible.
        nixpkgs = nixpkgs;
        specialArgs = { inherit inputs; system = "aarch64-linux"; };
        modules = [
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.lalobied = {
              imports = [ ./home-manager/server-home.nix ];
              home.stateVersion = "26.05";
            };
            home-manager.extraSpecialArgs = { inherit inputs; };
          }
          ({ ... }: { imports = piModules; })
          hostModule
        ];
      };
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
        homeExtraModules = [ inputs.nixvim-unstable.homeModules.nixvim ];
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
        homeExtraModules = [ inputs.nixvim-unstable.homeModules.nixvim ];
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

      # The bare Pi base. Also the source for packages.aarch64-linux.piImage,
      # so it pulls in nixos-raspberrypi's sd-image module.
      pitemplate = mkPiSystem [
        nixos-raspberrypi.nixosModules.raspberry-pi-4.base
        nixos-raspberrypi.nixosModules.sd-image
      ] ./templates/pitemplate.nix;

      # Jukebox host: same Pi base, plus the working raspberry-pi-4
      # bluetooth module (krnbt=on against the vendor kernel) so the
      # onboard BCM4345 actually comes up. librespot + audio extras
      # come from hosts/pijukeboxOS.nix's imports.
      pijukeboxOS = mkPiSystem [
        nixos-raspberrypi.nixosModules.raspberry-pi-4.base
        nixos-raspberrypi.nixosModules.raspberry-pi-4.bluetooth
      ] ./hosts/pijukeboxOS.nix;
    };

    packages.${system} =
      let
        nvim = inputs.nixvim.legacyPackages.${system}.makeNixvim
          (import ./config/nvim.nix);
      in
      {
        # Proxmox LXC template Build with
        # nix build .#packages.x86_64-linux.lxctemplate
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

    # Bootable SD card image for a Raspberry Pi 4. nixos-raspberrypi's
    # sd-image module produces this from the pitemplate config.
    # `nix build .#piImage`
    packages.aarch64-linux.piImage =
      self.nixosConfigurations.pitemplate.config.system.build.sdImage;
  };
}
