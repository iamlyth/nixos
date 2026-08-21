# pi2 Jail: Security Boundary and SSH Runner

`pi2` is a Bubblewrap-jailed coding agent built by `home-manager/repo/pi.nix`
with pinned `pi.nix` and `jail.nix` inputs. It is both a general development
environment and Ralph's Pi backend. The optional SSH integration is enabled
only by `home-manager/desktop-home.nix`.

## Effective boundary

The jail keeps Bubblewrap's private PID, IPC, mount, user, UTS, and cgroup
namespaces, private home, private `/tmp`, synthetic `/proc` and `/dev`, and
`--die-with-parent`. Both interactive Pi instances intentionally use jail.nix's
`no-new-session` mode so their TUIs remain attached to the controlling terminal
and receive resize events. This omits Bubblewrap's `--new-session` defense
against terminal-session attacks such as `TIOCSTI` input injection; it does not
relax the other namespaces. The jail does **not** expose host input, uinput,
hidraw, GPU, display, portal, system/user D-Bus, Docker, Podman, libvirt, direct
`/dev/snd` access, or unrelated runtime sockets.

Both instances expose the user's PipeWire socket and three pinned ALSA plugin
configuration files for the `@juicesharp/rpiv-voice` extension. The files are
mounted individually under `/etc/alsa/conf.d`; the host's activation-managed
`/etc/alsa` and `/etc/static` trees remain hidden. Its decibri addon records
through ALSA's PipeWire default device and receives no direct sound-device
mount. PipeWire is the audio authorization boundary: a jailed
process can capture inputs and interact with the user's audio graph to the
extent allowed by that PipeWire session. `LD_LIBRARY_PATH` exposes only the
pinned nixpkgs `libasound.so.2` needed by decibri's upstream prebuilt addon.
On hosts without a working user PipeWire session, `/voice` is unavailable.

The shared `network` combinator deliberately retains the host network
namespace. Consequently the agent can reach any destination allowed by host
routing and firewall policy, including localhost services, LAN, VPN/tailnet,
and the Internet. Network access is not an isolation boundary.

The Nix store is mounted read-only and the Nix daemon socket is intentionally
available with `NIX_REMOTE=daemon`. Jailed processes remain untrusted Nix
clients; workstation users and runner users must not be added to
`nix.settings.trusted-users`. The configured `max-jobs` and `cores` values are
cooperative Nix build-scheduling controls. They are not hard CPU, process,
memory, or disk limits; those require separately designed cgroup and storage
controls.

## Workspace policy

Before starting Bubblewrap, both `pi` and `pi2` validate the launch directory
inline in their generated outer wrappers:

1. canonicalizes the launch directory;
2. rejects `/`, the home directory, sensitive home configuration/credential
   directories, and system roots such as `/dev`, `/proc`, `/sys`, `/run`,
   `/etc`, `/nix`, `/boot`, `/usr`, and `/var`;
3. resolves the containing Git worktree root and canonicalizes it;
4. rejects linked worktrees or submodules whose Git metadata would require a
   mount outside the project; and
5. derives a readable, stable-per-project destination from the validated
   worktree basename, binds exactly that worktree read-write there (for example
   `/workspace/controller-box`), and changes to it.

Any canonical Git worktree outside sensitive paths is accepted. This permits
normal repositories such as `~/repos/controller-box` without granting the
whole repositories directory. A non-Git or unsafe launch directory always
produces a diagnostic and aborts before Bubblewrap starts; there is no broad
fallback mount.

## Credentials

The jail can read and exfiltrate every credential made available to it. This
includes the file-backed Firecrawl credential and provider authentication in
pi2's persistent agent home. Read-only mounts protect integrity only: a
read-only private key can still be copied and used elsewhere. Do not expose the
normal workstation `~/.ssh`, `SSH_AUTH_SOCK`, an agent socket, password stores,
or broader configuration directories.

## Dedicated SSH runner

`pimodule.pi2.sshRunner.enable` defaults to `false` and is enabled only in the
desktop Home Manager profile. When enabled, the outer wrapper requires the
real, non-symlink directory:

```text
~/.config/pi2-ssh-runner
```

Bubblewrap then mounts only that directory, read-only, at pi2's `~/.ssh` using
mandatory `--ro-bind` (not `--ro-bind-try`). Absence therefore fails closed both
before launch and if the directory disappears during setup.

Home Manager manages only the `factory-ssh` symlink inside this external
directory. It points directly to `${pkgs.openssh}/bin/ssh`, updates on each
activation when the pinned OpenSSH package changes, and remains rooted by the
active generation. The credential, config, and host-key files remain unmanaged
and outside Git; no manual symlink repair is required after nixpkgs updates.

The dedicated client config must select its dedicated identity, set
`UserKnownHostsFile ~/.ssh/known_hosts`, set `UpdateHostKeys no`, and require
strict host-key checking.
The pinned ED25519 host key must be verified through an authenticated channel;
do not trust unauthenticated `ssh-keyscan` output merely because it was
returned by the target address.

Client isolation is insufficient. The server must use a dedicated unprivileged
account and key with a root-owned forced-command wrapper, reject interactive
login and PTYs, disable SSH agent/TCP/X11 forwarding, and constrain command
execution and resources. The tested Debian runner additionally uses transient
systemd user scopes and untrusted multi-user Nix with sandboxing.

## Included tools

The curated closure retains shell and repository tools (`bash`, `git`, `jq`,
`ripgrep`, `vim`), archive/file tools, Node/Bun/pnpm/yarn, Python/uv, C/C++
toolchains and build systems, diagnostics (`gdb`, `strace`, `lsof`,
`valgrind`), Nix quality tools (`nixfmt-rfc-style`, `statix`, `deadnix`,
`shellcheck`, `shfmt`), and network tools (`curl`, `wget`, `openssh`, `rsync`,
`netcat`). `systemd` and D-Bus executables are present, but no host bus socket
is mounted. The declarative Pi extension set also includes
`@juicesharp/rpiv-voice`; its first `/voice` run downloads and extracts the
Whisper model into each instance's separate persistent home.

## Build and generated-wrapper inspection

These are build-only operations; they do not activate a generation:

```bash
# Evaluate the target system.
nix eval --raw \
  .#nixosConfigurations.desktopOS.config.system.build.toplevel.drvPath

# Build Home Manager without activating it.
hm_out=$(nix build --no-link --print-out-paths \
  .#nixosConfigurations.desktopOS.config.home-manager.users.lalobied.home.activationPackage)

# Resolve the installed outer pi2 wrapper.
outer=$(readlink -f "$hm_out/home-path/bin/pi2")
printf 'outer=%s\n' "$outer"
less "$outer"

# The outer script's final exec names the generated pi.nix package. Resolve
# that bin/pi and inspect it and the jail.nix Bubblewrap launcher it references.
grep -nE 'PI_JAIL_WORKSPACE_SOURCE|pi2-ssh-runner|^exec .*/bin/pi' "$outer"
inner=$(grep -E '^exec .*/bin/pi ' "$outer" | tail -1 | awk '{gsub(/"/, "", $2); print $2}')
printf 'inner=%s\n' "$(readlink -f "$inner")"
less "$(readlink -f "$inner")"
```

Generated-wrapper inspection means reading these built scripts and their
referenced store paths. It is distinct from a runtime smoke test: `pi2 echo
test` is not a wrapper-inspection or Bubblewrap dry-run command and must not be
used as one.

Useful checks:

```bash
nixfmt-rfc-style --check flake.nix home-manager/desktop-home.nix \
  home-manager/repo/pi.nix
nix flake check
```

When inspecting generated scripts, verify that resize-compatible mode omits
`--new-session`, while retaining `--unshare-user`, `--unshare-ipc`,
`--unshare-pid`, `--unshare-uts`, `--unshare-cgroup`, `--die-with-parent`, the
mandatory `--ro-bind .../.config/pi2-ssh-runner .../.ssh`, and the validated
`--bind "$PI_JAIL_WORKSPACE_SOURCE" "$PI_JAIL_WORKSPACE_DESTINATION"`, and
`--chdir "$PI_JAIL_WORKSPACE_DESTINATION"`. Also verify the absence of the
workstation's normal `.ssh`, `SSH_AUTH_SOCK`, `/dev/snd`, other host devices,
display/DBus/container sockets, and unrelated `/run/user` paths. The only
expected audio mounts are the three files under `/etc/alsa/conf.d` and the
current user's `$XDG_RUNTIME_DIR/pipewire-0` socket; `/etc/static` must remain
absent.

## Optional pre-activation smoke test

If the built wrapper can safely use the current user's persistent pi2 home and
the current checkout is a safe Git worktree, running `"$hm_out/home-path/bin/pi2"
--help` exercises validation and jail startup without switching generations.
It is still a real agent launch, not a dry run; skip it if that is undesirable.
Never print private-key contents during validation.

Do not run `nixos-rebuild switch`, `home-manager switch`, reboot, or otherwise
activate automatically.

## Acceptance after human activation

From fresh interactive `pi` and `pi2` sessions, run `/voice`. The first run
needs network access and roughly 650 MB of temporary free space for the model;
later runs are offline. Confirm that dictation opens, captures the default
microphone, and inserts the transcript. If capture fails, inspect
`~/.config/rpiv-voice/errors.log` inside the corresponding persisted jail
home.

For the optional SSH runner, from a fresh pi2 session run:

```bash
ssh dev-runner-vm 'id && pwd && systemctl --user is-system-running && nix --version'
```

Expected properties: user `devrunner`, no root/sudo groups, working directory
`/home/devrunner`, user manager `running`, and a responding Nix CLI.

Then confirm commandless login remains rejected:

```bash
ssh dev-runner-vm
```

Expected:

```text
PTY allocation request failed on channel 0
Interactive login is disabled; provide a runner command.
```
