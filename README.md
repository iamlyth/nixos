# NixOS Configuration

Declarative NixOS configuration suite managed via Nix Flakes. One repository, multiple targets: bare-metal desktops and laptops, Proxmox VMs, Proxmox LXC containers, an NVIDIA Jetson Orin Nano, and WSL.

## Quick Start

Get a shell with flakes + git available (handy on a fresh installer):

```bash
nix-shell -p git --run "nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git"
```

Apply a configuration:

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

## Repository Structure

| Path | Purpose |
|------|---------|
| `flake.nix` | Inputs + `nixosConfigurations` for every host, plus the `nvim`, `shell`, and `lxctemplate` package outputs. |
| `lib/mkSystem.nix` | Factory that wires home-manager into each `nixosSystem` so the boilerplate stays in one place. |
| `hosts/` | Hardware-specific NixOS modules for bare-metal / VM hosts. |
| `containers/` | NixOS modules for Proxmox LXC hosts + the LXC base template. |
| `modules/` | Reusable system modules. `modules/repo/*.nix` are toggleable services; the rest are core capabilities. |
| `home-manager/` | User-space layer. `home-manager/repo/*.nix` are atomic tool configs; `*-home.nix` are role profiles. |
| `config/` | Pure, framework-agnostic configuration data (`nvim.nix`, `zsh.nix`), consumed by both home-manager and standalone package outputs. |
| `pkgs/` | Custom package derivations exposed via `packages.<system>`. |

## Hosts

| Name | Platform | Role |
|------|----------|------|
| `desktopOS` | Framework Desktop (AMD AI Max) | Daily-driver desktop with gaming + local AI (Ollama/Open-WebUI). |
| `laptopOS` | Framework 13 (13th-gen Intel) | Daily-driver laptop. LUKS + TPM2 + lanzaboote secure boot. |
| `mediaOS` | Proxmox VM (x86_64) | Media stack: Plex, Radarr, Sonarr, SAB (VPN-confined). |
| `tatchiOS` | NVIDIA Jetson Orin Nano (aarch64) | Local AI host. |
| `wsl` | Windows Subsystem for Linux (x86_64) | Portable dev environment. |
| `paperLXC` | Proxmox LXC | Paperless-ngx + FTP intake. |
| `photoLXC` | Proxmox LXC | Immich photo library. |

## Common Workflows

```bash
sudo nixos-rebuild dry-build --flake .#<hostname>   # try without applying
sudo nixos-rebuild switch    --flake .#<hostname>   # apply
nix flake update                                    # bump all inputs
nix flake update nixpkgs                            # bump one input
nix flake check                                     # validate
```

Always commit `flake.lock` after updating inputs.

## Proxmox LXC Containers

Build the base LXC template:

```bash
nix build .#lxctemplate
```

The result symlink contains a `.tar.xz` template. Copy it into the Proxmox node's template store:

```bash
scp result/tarball/nixos-system-x86_64-linux.tar.xz \
    root@<proxmox-host>:/var/lib/vz/template/cache/
```

Create the container in Proxmox from that template, then SSH in, clone this repo, and switch to the LXC host config:

```bash
sudo nixos-rebuild switch --flake .#paperLXC   # or .#photoLXC
```

Notes:

- The container hosts expect CIFS credentials at `/etc/nixos/.secrets/smbcred` (kept out of git).
- `lxctemplate.nix` is the bootstrap template only — it's not in `nixosConfigurations`. It's built via `packages.lxctemplate` using `nixos-generators`.

## Portable Shell on Any Machine

The fastest way to feel at home on a strange nix machine:

```bash
nix run github:iamlyth/nixos#shell
```

You land in a zsh session with the same oh-my-zsh setup, aliases, history settings, autosuggestions, and syntax highlighting — plus `nvim` on `$PATH` and `EDITOR=nvim`. Nothing is written to `$HOME`; the launcher uses a self-contained `ZDOTDIR` inside the nix store.

The shell and the home-manager `zshmodule` both consume `config/zsh.nix`, so they stay in lockstep.

## Running `nvim` from Another Flake

```bash
nix run   github:iamlyth/nixos#nvim   # ad-hoc
nix build github:iamlyth/nixos#nvim   # build locally → ./result/bin/nvim
```

Or reference it from another flake:

```nix
{
  inputs.lyth-nixos.url = "github:iamlyth/nixos";

  outputs = { self, nixpkgs, lyth-nixos, ... }: {
    environment.systemPackages = [ lyth-nixos.packages.x86_64-linux.nvim ];
  };
}
```

The same `config/nvim.nix` powers both the standalone package and the home-manager `programs.nixvim` block.

## Channels

| Input | Branch |
|-------|--------|
| `nixpkgs`, `home-manager`, `nixvim` | `release-26.05` |
| `nixpkgs-unstable`, `home-manager-unstable` | rolling (used by `desktopOS` and `laptopOS`) |
| `nixpkgs-ollama` | pinned commit (temporary workaround for an upstream ollama/pi-coder bug) |

`unstable = true` in a `mkSystem` invocation selects the rolling channels.

## See Also

- `AGENTS.md` — operating manual for AI agents working in this repo.
- `lib/mkSystem.nix` — the system factory and its parameters.
