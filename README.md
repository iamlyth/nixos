# NixOS Configuration

Declarative NixOS configuration suite managed via Nix Flakes. One repository, multiple targets: bare-metal desktops and laptops, Proxmox VMs, Proxmox LXC containers, an NVIDIA Jetson Orin Nano, a Raspberry Pi 4, and WSL.

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
| `flake.nix` | Inputs + `nixosConfigurations` for every host, plus the `nvim`, `lxctemplate`, and `piImage` package outputs. |
| `lib/mkSystem.nix` | Factory that wires home-manager into each `nixosSystem` so the boilerplate stays in one place. |
| `hosts/` | Per-host NixOS modules — bare-metal, VMs, Proxmox LXC hosts, the Pi jukebox. |
| `templates/` | Image-source modules consumed by `packages.*` outputs (Proxmox LXC tarball, Raspberry Pi SD image). Not referenced by `nixosConfigurations`. |
| `modules/` | Reusable system modules. `modules/repo/*.nix` are toggleable services; the rest are core capabilities. |
| `home-manager/` | User-space layer. `home-manager/repo/*.nix` are atomic tool configs; `*-home.nix` are role profiles. |
| `config/` | Pure, framework-agnostic configuration data (`nvim.nix`), consumed by both home-manager and the standalone `packages.nvim` output. |
| `scripts/` | Maintenance tooling. `update-deps.sh` updates the manually pinned dependencies in `home-manager/repo/pins.json` (see below). |

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
| `pijukeboxOS` | Raspberry Pi 4 (aarch64) | Spotify Connect endpoint + Bluetooth audio sink. |

## Common Workflows

```bash
sudo nixos-rebuild dry-build --flake .#<hostname>   # try without applying
sudo nixos-rebuild switch    --flake .#<hostname>   # apply
nix flake update                                    # bump all inputs
nix flake update nixpkgs                            # bump one input
nix flake check                                     # validate
scripts/update-deps.sh --check                      # manual pins: what's outdated
scripts/update-deps.sh <target>                     # manual pins: update (or `all`)
```

Always commit `flake.lock` after updating inputs.

## Manually Pinned Dependencies

Some sources are pinned outside `flake.lock`, so `nix flake update` never
touches them. All of their pin values live in `home-manager/repo/pins.json`,
which the nix modules read via `importJSON`:

| Pin | Consumed by | What it is |
|-----|-------------|------------|
| `claude-plugins-official`, `claude-skills` | `home-manager/repo/claude.nix` | Claude Code plugin and skill sources (GitHub rev + hash). |
| `claude-context-mode`, `claude-context-mode-deps` | `home-manager/repo/claude.nix` | The context-mode plugin for Claude Code, plus the `npmDepsHash` for its runtime dependencies. |
| `pi-extensions` | `home-manager/repo/pi.nix` | `npmDepsHash` for the pi coding-agent extensions (`context-mode`, `@tintinweb/pi-subagents`); their versions live in `home-manager/repo/pi-extensions-deps/package.json`. |

Update them with `scripts/update-deps.sh`: `--check` reports what is outdated
without changing anything, a target name updates one pin (mirroring
`nix flake update <input>`), and `all` updates everything. The script bumps
versions and revs, regenerates npm lockfiles, recomputes `npmDepsHash`
values, and runs a verification build. Don't hand-edit hashes.

Targets are derived from the data, not hardcoded: adding an entry to
`pins.json` (with its `type` field; see the script header for the schema) or
a package to a managed npm dir makes it updatable with no script changes.
`scripts/update-deps.sh --help` lists the current targets.

Pi and Claude Code extensions are never installed imperatively on a host
(`pi install npm:...` and friends); they load from the nix store via these
pins so updates stay git-visible and revertible.

## Overlay Policy

Overlays are temporary workarounds by default. Each one carries an
`Overlay added YYYY-MM-DD` tag plus a `Checked YYYY-MM-DD` note stating the
upstream issue it waits on, and gets deleted once the fix reaches the locked
rev. Overlays that are permanent by design (the CachyOS kernel overlay) say
so in their comment. The same convention covers pinned-commit flake inputs
like `nixpkgs-ollama`.

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
- `templates/lxctemplate.nix` is the bootstrap template only — it's not in `nixosConfigurations`. It's built via `packages.lxctemplate` using `nixos-generators`.

## Raspberry Pi SD Image

The Pi targets use [`nvmd/nixos-raspberrypi`](https://github.com/nvmd/nixos-raspberrypi) for kernel, firmware, DTB, bootloader, and the sd-image build. Stock `nixos-hardware` ships a device tree on which onboard Bluetooth doesn't come up; this flake builds against the Raspberry Pi vendor (RPi-Trading) kernel + DTBs — the same set RPi OS uses — where BT works correctly. The repo's own cachix is wired into the flake's `nixConfig` so kernel builds come down prebuilt instead of compiling locally.

Build the SD image from an aarch64 host, or from x86_64 with `boot.binfmt.emulatedSystems = [ "aarch64-linux" ];` enabled — `desktopOS` and `laptopOS` already do:

```bash
nix build .#piImage
# equivalent to:
# nix build .#nixosConfigurations.pitemplate.config.system.build.sdImage
```

`result/sd-image/*.img.zst` is the bootable image. Flash it to an SD card, boot the Pi, log in as `lalobied` / `nixos`, then specialize the host:

```bash
sudo nixos-rebuild switch --flake github:iamlyth/nixos#pijukeboxOS
```

Notes:

- `templates/pitemplate.nix` is the shared host base — `hosts/pijukeboxOS.nix` imports it and layers librespot + Bluetooth on top.
- All Pi-specific knobs (kernel, firmware blobs, U-Boot, `config.txt`, `krnbt=on`, fileSystems) live in `nixos-raspberrypi`'s `raspberry-pi-4.{base,bluetooth}` modules wired in at the flake level — `pitemplate.nix` itself is just host config (ssh, user, hostname).
- Setup, Bluetooth-speaker pairing, and per-host librespot tweaks: see [`docs/pijukebox.md`](docs/pijukebox.md).

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
