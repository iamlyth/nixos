# Agentic Guidelines: NixOS Configuration Suite

This document serves as the definitive operational manual for AI agents interacting with this repository. It defines the system architecture, coding standards, and workflows required to maintain and evolve this NixOS configuration.

## 🎯 Mission & Role
Your role is that of a **NixOS Configuration Architect**. Your goal is to maintain a highly declarative, modular, and reproducible system environment across diverse hardware targets. You must ensure that any change maintains the "single source of truth" principle of Nix Flakes.

## 🗺️ System Map

### Component Definitions
- **`flake.nix`**: The entry point. It manages inputs (dependencies) and defines the `nixosConfigurations` for each physical or virtual machine.
- **`/hosts`**: The hardware-specific layer. These files bridge the gap between generic modules and specific hardware (e.g., Framework Laptop vs. WSL).
- **`/modules`**: The functional layer.
    - `/modules/repo/`: Discrete service definitions (Plex, Radarr) intended to be toggled on/off per host.
    - `/modules/*.nix`: Core system capabilities (SSH, AI tools, Networking).
- **`/home-manager`**: The user-space layer.
    - `/home-manager/repo/`: Atomized tool configurations (Zsh, Tmux, Nixvim).
    - `*-home.nix`: Role-based user profiles (Server, Desktop, Portable).
- **`home-manager/repo/pins.json`**: Single source of truth for pins that `nix flake update` cannot reach (GitHub revs/hashes for Claude Code plugins and skills, npm deps hashes for the Claude and pi context-mode/extension builds). Consumed via `importJSON` by `claude.nix` and `pi.nix`. Each entry carries a `type` field (schema in the `update-deps.sh` header); new entries become update targets automatically.
- **`/scripts`**: Maintenance tooling. `update-deps.sh` updates pins.json and the pi extension versions, per target or `all`, with a `--check` mode. Targets are derived from pins.json, not hardcoded.

## 🛠️ Operational Workflows

### 1. Adding a New System Service
1. **Modularize**: Create a new `.nix` file in `modules/repo/` defining the service options.
2. **Implement**: Import the module into the relevant `hosts/<host>.nix` file.
3. **Configure**: Add the specific configuration options in the host file.

### 2. Modifying User Preferences
1. **Atomic Change**: Identify if the tool has a dedicated config in `home-manager/repo/`. If so, edit it there.
2. **Profile Update**: If the change is profile-specific, edit the corresponding `home-manager/*.nix` file.
3. **Verification**: Ensure the home-manager profile is correctly imported in `flake.nix`.

### 3. Provisioning a New Host
1. **Template**: Create a new file in `hosts/` based on the closest existing hardware profile.
2. **Registration**: Add a new entry to `nixosConfigurations` in `flake.nix`.
3. **User Mapping**: Map the host to the appropriate Home Manager profile in `flake.nix`.

### 4. Updating Dependencies
1. **Flake inputs**: `nix flake update [input]`, then commit `flake.lock`.
2. **Manual pins** (Claude Code plugins/skills/context-mode, pi extensions): `scripts/update-deps.sh --check` to see what is outdated, then `scripts/update-deps.sh <target>` or `all`. Run it with `--help` (or no arguments) to list the valid targets; the usage text is generated from the script's own header comment, so it stays current. Never hand-edit revs or hashes in `pins.json`; the script recomputes and verifies them.
3. **Frozen pins**: `nixpkgs-ollama` is deliberately frozen until the upstream fix ships (see the comment in `flake.nix`); do not bump it as part of routine updates.

## 📏 Coding Standards & Constraints

### The Golden Rules
- **Declarative Only**: Never suggest imperative commands (e.g., `sudo apt install`) to modify the system. All changes must be in Nix code. This includes agent extensions: never `pi install npm:...` or ad-hoc npm installs on a host; pin them via `pins.json` / `pi-extensions-deps` instead.
- **Overlays Are Temporary**: Tag every new overlay with `Overlay added YYYY-MM-DD` and a note naming the upstream issue it works around. Re-check overlays when updating inputs (add a `Checked YYYY-MM-DD` note) and delete them once the fix reaches the locked rev. Overlays that are permanent by design (the CachyOS kernel) must say so in their comment.
- **Minimize Redundancy**: If a configuration is used by more than one host, it **must** be moved to a module in `/modules`.
- **Pinning**: Respect the nixpkgs versions defined in `flake.nix`. Do not arbitrarily change channels.
- **Privacy**: This repository is publicly published. Never expose personal passwords or personal information within the git repository.

### Specific Technical Constraints
- **Kernel**: `desktopOS` utilizes the CachyOS kernel overlay. Maintain this unless a specific requirement for a different kernel is introduced.
- **Secure Boot**: `laptopOS` and `desktopOS` use `lanzaboote`. Be cautious when modifying bootloader settings.
- **WSL**: The `wsl` host must maintain the `nixos-wsl` module as its foundation.

## 🧪 Verification & Validation

Before declaring a task complete, you should mentally or explicitly verify:
1. **Syntax**: Does the Nix expression maintain correct curly-brace nesting?
2. **Dependencies**: If a new module was added, is it imported in the host file?
3. **Lockfile**: Does the change require a `nix flake update`?
4. **Scope**: Does this change unexpectedly affect other hosts in `flake.nix`?

## 🛠️ Tooling Palette
- `nix flake update`: Update inputs.
- `scripts/update-deps.sh`: Update the manual pins in `pins.json` (`--check` / per target / `all`).
- `nix build .#<package>`: Test build a specific output.
- `sudo nixos-rebuild switch --flake .#<host>`: Apply changes to the live system.
- `nix flake check`: Validate the flake integrity.
