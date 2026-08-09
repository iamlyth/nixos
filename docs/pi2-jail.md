# pi2 Jail: Security Boundary and Development Environment

The `pi2` instance is a Bubblewrap-jailed coding agent built on
[pi.nix](https://github.com/lukasl-dev/pi.nix) and
[jail.nix](https://git.sr.ht/~alexdavid/jail.nix).  It serves as the
Ralph orchestrator's Pi backend and as a general-purpose development
environment for Controller-Box and other software-development campaigns.

This document covers the default capability boundary, included tools,
the optional SSH runner mechanism, how to inspect the effective
Bubblewrap arguments, build-only validation commands, warnings against
broadening the jail, and the remaining steps after the hardware VM exists.

## Default Jail Capability Boundary

The jail is assembled by `home-manager/repo/pi.nix` and uses the
combinator API from the pinned `jail.nix` flake input.  The base
permissions (applied to every jail) provide:

- Fake `/proc` and `/dev` (bwrap `--proc` / `--dev`)
- tmpfs at `/tmp` and `~` (home)
- `/bin/sh` from Nix-provided bash
- Fake `/etc/passwd` and `/etc/group` (root + calling user only)
- Runtime closure of the jailed binary bind-mounted read-only from
  `/nix/store`
- Environment cleared except `LANG`, `HOME`, `TERM`

The pi2-specific permissions layer on top:

| Capability | Status | How |
|---|---|---|
| Network (TCP/UDP/TLS) | ✅ granted | `network` combinator (shares net namespace, bind-mounts `/etc/hosts`, `/etc/resolv.conf`, `/etc/ssl`, etc.) |
| Persistent private home | ✅ granted | `persist-home "pi2"` → `~/.local/share/jail.nix/home/pi2` |
| Nix daemon (untrusted) | ✅ granted | read-only `/nix/store` + `/nix/var/nix/daemon-socket`, `NIX_REMOTE=daemon` |
| Firecrawl API key | ✅ file-backed | `--ro-bind-try /etc/nixos/.secrets/firecrawl-api-key` |
| Current project workspace | ✅ writable | `--bind "$PWD" "/workspace/$(basename $PWD)"` |
| New terminal session (`--new-session`) | ✅ restored | bwrap default (not disabled) |
| `/dev/input`, `/dev/uinput`, `/dev/hidraw*`, `/dev/dri/*` | ❌ not exposed | |
| Host X11 / Wayland / PipeWire / PulseAudio | ❌ not exposed | |
| Host system/user DBus sockets | ❌ not exposed | |
| Docker / Podman / libvirt sockets | ❌ not exposed | |
| Host SSH agent / `~/.ssh` | ❌ not exposed | |
| Host `/usr`, `/etc`, `/nix/store` (writable) | ❌ not exposed | `/nix/store` is read-only |
| Shared host `/tmp` | ❌ not exposed | tmpfs inside jail |
| `sudo` / setuid / Nix trusted-user | ❌ not available | `nix.settings.trusted-users = [ "root" ]` |

### Namespaces

The jail unshares all namespaces except `net` (network is shared for
API access and Git operations):

- `--unshare-ipc` — private IPC namespace
- `--unshare-pid` — private PID namespace
- `--unshare-uts` — private UTS namespace (hostname = `jail`)
- `--unshare-cgroup` — private cgroup namespace
- `--unshare-user` — private user namespace
- `--new-session` — new terminal session (restored for pi2)
- `--die-with-parent` — jail dies when the launching process exits

### Credential Boundary

The jail has network access and can read any file bind-mounted into it.
File-backed secrets (e.g., `FIRECRAWL_API_KEY.file`) avoid Nix-store
leakage — the secret value never enters the store — but the jailed agent
**can read the file at runtime and exfiltrate it over the network**.

Mitigations in place:

- Secrets are bind-mounted **read-only**.
- The Firecrawl key is the only secret currently exposed.
- The host's `~/.ssh` directory and SSH agent are **not** exposed to pi2.

Future improvement: replace file-backed secrets with a capability/proxy
that validates requests rather than exposing the raw credential.

## Included General Development Tools

The shared package closure (`sharedJailPkgs` in `pi.nix`) provides the
following categories.  These are added via `add-pkg-deps`, which puts
each package's `bin/` directory on `PATH` and includes its runtime
closure in the bind-mounted Nix store paths.

### Shell and repository utilities

bash, coreutils, diffutils, fd, findutils, gawk, git, gnugrep, gnused,
jq, ripgrep, vim, which, tree

### Archives, patches, and file inspection

file, patch, gnutar, gzip, bzip2, xz, zip, unzip

### Language runtimes and package managers

nodejs, bun, pnpm, yarn, python313, uv

### Native compilation and build systems

gcc, gnumake, cmake, ninja, meson, pkg-config, clang, clang-tools, lld,
lldb, autoconf, automake, libtool, ccache, bear, mold, patchelf

### Debugging and inspection

gdb, valgrind, strace, lsof, procps, linuxPackages.perf, util-linux
(`flock`)

### Quality tools

shellcheck, shfmt, nixfmt-rfc-style, statix, deadnix, cppcheck, lcov

### Data tools

sqlite

### Network tools

cacert, curl, wget, openssh, netcat-openbsd, rsync

### Service/DBus diagnostics (executables only — no host sockets)

systemd (`systemctl`, `busctl`, `journalctl`, `udevadm`), dbus
(`dbus-daemon`, `dbus-run-session`, `dbus-monitor`)

> **Important:** These binaries are available as executables inside the
> jail. They do **not** imply access to the host's system bus, user
> session bus, or any other host socket. `systemctl` and `busctl` will
> fail to connect unless the agent sets up its own `dbus-daemon`
> session inside the jail (e.g., via `dbus-run-session`).

### Nix

The Nix CLI is available for parsing and local operations. The daemon
socket is bind-mounted read-only so agents can evaluate, build, and run
project-provided Nix shells and flake apps. The agent user is **not** in
`nix.settings.trusted-users`, so Nix daemon access is untrusted and
cannot escalate to root.

## SSH Runner (Disabled by Default)

The `pimodule.pi2.sshRunner.enable` option (default `false`) controls
whether a dedicated SSH config directory is bind-mounted into the pi2
jail.

When enabled, `~/.config/pi2-ssh-runner` is bind-mounted read-only at
`~/.ssh` inside the jail. The user places an SSH `config` file with a
`controller-box-vm` alias and a dedicated private key in that directory.

### Threat model

The jailed agent **can use any credential exposed to it**. The
`--ro-bind-try` means the mount is a no-op if the directory does not
exist, but when it does exist, the agent can read the private key and
connect to any host reachable from the jail's network namespace.

Mitigations:

- **Disabled by default** — no SSH config is mounted unless explicitly
  enabled.
- **Dedicated directory** — the host's real `~/.ssh` is never exposed.
  Only `~/.config/pi2-ssh-runner` is mounted.
- **Read-only** — the agent cannot modify the SSH config or add keys.
- **No SSH agent** — the host's SSH agent socket is not exposed.

### Remaining steps after the hardware VM exists

1. Create `~/.config/pi2-ssh-runner/` on the host.
2. Generate a **dedicated** SSH key pair for the disposable VM
   (`ssh-keygen -t ed25519 -f ~/.config/pi2-ssh-runner/controller_box_vm`).
   Do not reuse any existing key.
3. Write `~/.config/pi2-ssh-runner/config` with a `controller-box-vm`
   alias pointing at the VM's hostname/IP, port, and the dedicated key.
   Keep `StrictHostKeyChecking yes` (the default).
4. Add the VM's host key to `~/.config/pi2-ssh-runner/known_hosts` (run
   `ssh-keyscan` after the VM is up).
5. Set `pimodule.pi2.sshRunner.enable = true` in the host's Home Manager
   config and rebuild.
6. The future restricted runner / forced-command design on the VM side
   is handled separately — the Nix config here only prepares the client
   side.

## Resource Controls

### Nix build concurrency

The `NIX_CONFIG` environment variable inside the jail includes:

```
experimental-features = nix-command flakes
max-jobs = 4
cores = 8
```

These limit the number of concurrent Nix builds (`max-jobs`) and the
cores available to each build (`cores`). They are conservative defaults
that prevent runaway parallel builds from exhausting the host. Override
them by changing the `nixDaemonJailAccess` function in `pi.nix`.

### Process and memory limits (recommended, not implemented)

Bubblewrap does not natively support cgroup-based resource limits. The
recommended follow-up is to wrap the pi2 launcher in `systemd-run` to
place it in a dedicated cgroup slice:

```bash
systemd-run --user \
  --slice=pi2.slice \
  --property=MemoryMax=16G \
  --property=TasksMax=512 \
  -- pi2 "$@"
```

This is not implemented in the Nix config because:

- It requires `systemd-run` on the host, which may not be available on
  all targets (WSL, non-systemd hosts).
- It would change the pi2 wrapper's behaviour in ways that need testing
  on the actual desktop host.
- The Nix build concurrency limits above handle the most common runaway
  scenario (parallel Nix builds).

### Disk and store growth

The jail sees `/nix/store` read-only. Garbage collection must be
performed on the host. Recommended periodic maintenance:

```bash
sudo nix-collect-garbage --older-than 30d
sudo nix optimise-store
```

## How to Inspect Effective Bubblewrap Arguments

Because the jail wrapper is a shell script generated by Nix, you can
inspect the effective bwrap arguments without running the jail:

```bash
# Option 1: Read the generated wrapper script
# After building, the wrapper is at the package's bin/pi path.
# Use nix to print it:
nix eval --raw .#nixosConfigurations.desktopOS.config.home-manager.users.lalobied.home.packages \
  # find the pi2 derivation and inspect its text

# Option 2: Dry-run the wrapper with a harmless command
# The wrapper script sets RUNTIME_ARGS and runs bwrap.
# You can source the script to see the args without executing pi:
pi2 --help  # or
pi2 echo test  # launches the jail briefly

# Option 3: Inspect the generated shell script from a build
nix build .#nixosConfigurations.desktopOS.config.home-manager.users.lalobied.home.packages
# Then look through the result/ symlinks for the pi2 wrapper script.
# The script contains the full bwrap invocation with all --ro-bind, --tmpfs, etc.
```

## Build-Only Validation Commands

**Do not run `nixos-rebuild switch` or `home-manager switch` to
validate.** Use build-only commands:

```bash
# Evaluate the full system configuration without applying:
nixos-rebuild dry-build --flake .#desktopOS

# Or build the home-manager activation package:
nix build .#nixosConfigurations.desktopOS.config.home-manager.users.lalobied.home.activationPackage

# Check the flake:
nix flake check

# Format changed files:
nix fmt  # or: nixfmt-rfc-style <file>
```

## Warnings: Do Not Broaden the Default Jail

The following are intentionally **not exposed** to the pi2 jail. Do not
add them as shortcuts:

- **`/dev/input` or any keyboard/mouse event node** — controller
  acceptance runs on the remote disposable VM, not the workstation.
- **`/dev/uinput`** — creating virtual input devices on the host is a
  privilege escalation risk.
- **`/dev/hidraw*`** — raw HID access bypasses the input stack.
- **`/dev/dri/card*` or render nodes** — GPU access is not needed for
  development builds.
- **Host X11 sockets or Xauthority** — display access allows key
  logging and screen scraping.
- **Host Wayland / PipeWire / PulseAudio / portal sockets** — audio and
  display access leaks user-session data.
- **Raw `/run/dbus/system_bus_socket`** — system bus access allows
  service control and privilege escalation.
- **Full user-session DBus socket or all of `/run/user/$UID`** —
  exposes the user session including secrets and IPC channels.
- **Docker / Podman / libvirt sockets** — container access is
  equivalent to root.
- **Host SSH agent** — exposes all keys loaded in the agent.
- **Writable `/usr`, `/etc`, `/nix/store`, or host home** — write access
  to these defeats the jail's integrity boundary.

If a capability seems essential, explain the exact acceptance path and
safer alternative before adding it. Prefer explicit opt-in profiles
over broadening the default jail.

## Optional Future Profiles

The module architecture supports clean opt-in profiles via
`pimodule.pi2` options. Future launchers could opt into:

- A dedicated runner-SSH config/identity (implemented: `sshRunner.enable`)
- A single Wayland socket
- One DRM render node
- One reviewed controller event node plus corresponding udev metadata
- A filtered `xdg-dbus-proxy` for one service

None of these are enabled by default. Controller-Box hardware
acceptance is intended to run on the remote disposable VM, not on the
workstation.