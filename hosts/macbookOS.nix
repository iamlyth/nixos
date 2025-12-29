# darwin.nix

{ pkgs, ... }:

{
    # List packages installed in system profile. To search by name, run:
    # $ nix-env -qaP | grep wget
    environment.systemPackages =
    [ ];
    ids.gids.nixbld = 350;
    # Necessary for using flakes on this system.
    nix.settings.experimental-features = "nix-command flakes";

    # Used for backwards compatibility, please read the changelog before changing.
    # $ darwin-rebuild changelog
    system.stateVersion = 6;

    # The platform the configuration will be used on.
    nixpkgs.hostPlatform = "x86_64-darwin";

    users.users.lalobied = {
        name = "lalobied";
        home = "/Users/lalobied";
    };
}
