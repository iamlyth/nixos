# Factory for building a nixosConfiguration.
#
# Called as `mkSystem { inherit inputs; } { hostModule = ...; homeProfile = ...; ... }`.
# All nixosConfigurations in flake.nix go through here so the home-manager
# wiring, channel selection, and user setup stays consistent.
{ inputs }:

{
  # Path to the host's main NixOS module (e.g. ./hosts/desktopOS.nix).
  hostModule,

  # Path to the home-manager profile for the user (e.g. ./home-manager/desktop-home.nix).
  homeProfile,

  # Username that owns the home-manager profile.
  username ? "lalobied",

  # When true, build against nixpkgs-unstable + home-manager-unstable.
  unstable ? false,

  # Extra modules to import inside the home-manager user profile
  # (e.g. [ inputs.nixvim.homeModules.nixvim ]).
  homeExtraModules ? [ ],

  # Extra NixOS modules for the system (overlays, lanzaboote, hardware profiles, ...).
  extraModules ? [ ],

  # Extra entries to merge into specialArgs (e.g. { inherit stablenix; }).
  # `inputs` is always passed through.
  specialArgs ? { },
}:

let
  nixpkgs = if unstable then inputs.nixpkgs-unstable else inputs.nixpkgs;
  home-manager = if unstable then inputs.home-manager-unstable else inputs.home-manager;
in
nixpkgs.lib.nixosSystem {
  specialArgs = { inherit inputs; } // specialArgs;
  modules = [
    home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.users.${username}.imports = [ homeProfile ] ++ homeExtraModules;
      home-manager.extraSpecialArgs = { inherit inputs; };
    }
    hostModule
  ] ++ extraModules;
}
