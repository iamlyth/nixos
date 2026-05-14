---
name: module-authoring
description: Assists in creating modularized NixOS services and home-manager configurations. Use this when adding new system services or user tools.
---

# Module Authoring

This skill ensures that new functionality is added to the NixOS configuration in a declarative, modular, and reproducible way, following the guidelines in `AGENTS.md`.

## Workflow for New System Services

1. **Modularize**: 
   - Create a new file in `modules/repo/<service-name>.nix`.
   - Use the standard NixOS module pattern:
     ```nix
     { config, lib, pkgs, ... }:
     with lib.options;
     {
       options = {
         services.<name> = {
           enable = enable;
           setting = str;
         };
       };
       config = lib.mkIf config.services.<name>.enable {
         # Service implementation here
         systemd.services.<name> = { ... };
       };
     }
     ```
2. **Implement**:
   - Import the module in the relevant host file (e.g., `hosts/mediaOS.nix` or `hosts/desktopOS.nix`).
   - Add the module path to the `modules = [ ... ]` list.
3. **Configure**:
   - Set the options in the host file:
     ```nix
     services.<name>.enable = true;
     services.<name>.setting = "value";
     ```
4. **Verify**:
   - Run `nix flake check` to ensure basic syntax and flake integrity.

## Workflow for User-Space Tools (Home Manager)

1. **Atomic Config**:
   - If the tool is reusable, create a config in `home-manager/repo/<tool>.nix`.
2. **Profile Update**:
   - Import the tool into the appropriate role profile (e.g., `home-manager/desktop-home.nix`).
3. **Mapping**:
   - Ensure the profile is mapped to the user in `flake.nix`.

## Guiding Principles

- **Single Source of Truth**: All changes must be declarative. No imperative commands.
- **Minimize Redundancy**: If a config is used by $>1$ host, it **must** be a module in `/modules`.
- **Privacy**: Never commit passwords or secrets. Use `sops-nix` or similar if applicable, or keep them in separate non-git files.
