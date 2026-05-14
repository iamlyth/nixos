# NixOS Configuration

This repository contains a complete, declarative NixOS configuration suite managed via Nix Flakes. It provides tailored system and user configurations for multiple hardware targets and usage scenarios.

## 📂 Repository Structure

- `/hosts`: Machine-specific system configurations.
- `/home-manager`: User-level configurations (dotfiles, user apps).
- `/modules`: Shared system modules (e.g., Plex, Immich, Sway).
- `/containers`: LXC templates and specific container configs.

## 🛠️ Bootstrapping on a Fresh Install

### 1. Enable Flakes
By default, NixOS does not have Flakes enabled. You must first add the following to your `/etc/nixos/configuration.nix`:

```nix
nix.settings.experimental-features = [ "nix-command" "flakes" ];
```

Apply this change by running:
```bash
sudo nixos-rebuild switch
```

### 2. Clone this Repository
Clone this repo to your desired location (e.g., `~/nixos-config`):

```bash
git clone <your-repo-url> ~/nixos-config
cd ~/nixos-config
```

### 3. Apply the Flake Configuration
Once in the directory, you can switch your system to one of the predefined host configurations:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```
*(Replace `<hostname>` with `desktopOS`, `laptopOS`, `mediaOS`, etc.)*

> [!WARNING]  
> These configurations are tailored to specific hardware (e.g., Framework Laptops). Ensure you pick the host that matches your hardware, or modify the files in `/hosts` to fit your machine before applying.

## 🚀 Usage

### Applying a Configuration
To apply a configuration to your current system, ensure you have Nix Flakes enabled and run:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

**Example for desktop:**
```bash
sudo nixos-rebuild switch --flake .#desktopOS
```

### Building the LXC Template
To generate a Proxmox LXC template image:
```bash
nix build .#lxctemplate
```
