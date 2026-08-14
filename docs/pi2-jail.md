# pi2 Jail: Security Boundary and SSH Runner

`pi2` is a Bubblewrap-jailed coding agent built by `home-manager/repo/pi.nix`
with pinned `pi.nix` and `jail.nix` inputs. It is both a general development
environment and Ralph's Pi backend. The optional SSH integration is enabled
only by `home-manager/desktop-home.nix`.

## Effective boundary

The jail keeps Bubblewrap's private PID, IPC, mount, user, UTS, and cgroup
namespaces, private home, private `/tmp`, synthetic `/proc` and `/dev`,
`--die-with-parent`, and `--new-session`. It does **not** expose host input,
uinput, hidraw, GPU, display, audio, portal, system/user D-Bus, Docker, Podman,
libvirt, or unrelated runtime sockets.

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

The dedicated client config must select its dedicated identity, set
`UserKnownHostsFile ~/.ssh/known_hosts`, and require strict host-key checking.
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
is mounted.

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

When inspecting generated scripts, verify `--new-session`, mandatory
`--ro-bind .../.config/pi2-ssh-runner .../.ssh`, the validated
`--bind "$PI_JAIL_WORKSPACE_SOURCE" "$PI_JAIL_WORKSPACE_DESTINATION"`, and
`--chdir "$PI_JAIL_WORKSPACE_DESTINATION"`. Also verify the absence of the workstation's
normal `.ssh`, `SSH_AUTH_SOCK`, host devices, display/DBus/container sockets,
and unrelated `/run/user` paths.

## Optional pre-activation smoke test

If the built wrapper can safely use the current user's persistent pi2 home and
the current checkout is a safe Git worktree, running `"$hm_out/home-path/bin/pi2"
--help` exercises validation and jail startup without switching generations.
It is still a real agent launch, not a dry run; skip it if that is undesirable.
Never print private-key contents during validation.

Do not run `nixos-rebuild switch`, `home-manager switch`, reboot, or otherwise
activate automatically.

## Acceptance after human activation

From a fresh pi2 session, run:

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
