# Pi extension swap (one-time, run on the desktop)

Temporary runbook, delete after completing. Written 2026-07-14.

## What changed

`context-mode` (1.0.169) and `@tintinweb/pi-subagents` (0.14.1) are now
nix-pinned in `home-manager/repo/pi.nix`. Pi loads them from the read-only
nix store via `--extension` and `--skill` flags baked into its wrapper, the
same entry points their `pi` package.json fields declare. The copies
installed earlier with `pi install npm:...` still sit in `~/.pi/agent`;
after the rebuild those are duplicates and must be removed so pi does not
load every extension twice.

## 1. Pull and rebuild

```sh
git pull
sudo nixos-rebuild switch --flake .#desktopOS
```

## 2. Sanity-check pi still starts

Launch pi and confirm it comes up. The imperative copies are still installed
at this point, so this step only proves the rebuild broke nothing.

## 3. Remove the imperative copies

```sh
pi uninstall context-mode
pi uninstall @tintinweb/pi-subagents
```

The jailed wrapper passes `uninstall`, `list`, `install`, `update`, and
`config` straight through to pi, so this works from a normal shell. Run
`pi list` afterward; it should report nothing imperatively installed.

## 4. Check for leftovers

The agent dir the jail uses is the host's real `~/.pi/agent`:

```sh
ls -la ~/.pi/agent
cat ~/.pi/agent/settings.json
```

- Remove leftover extension directories or `node_modules` belonging to the
  two uninstalled packages.
- If `settings.json` still contains package or extension registration
  entries, remove those keys. Leave `defaultProvider` and `defaultModel`
  alone; those are managed by home-manager activation and get re-merged on
  every switch.
- Also check the jail's persisted home for strays (only exists if the host
  bind was ever missing):

```sh
ls ~/.local/share/jail.nix/home/pi-coder/.pi/agent 2>/dev/null
```

## 5. Restart pi and verify the pinned copies

Both extensions should still work, now loaded only from the nix store. The
"context-mode vX outdated, upgrade" nag should be quiet since the pin is
the latest release as of today; if upstream publishes a newer version later,
the nag returns until the pin is bumped (see below), but the code itself can
no longer drift.

## 6. Optional: the gemma4 A/B test

The 2026-07-14 derailment diagnosis still suspects context-mode's onboarding
block hurts a 26 to 31B model. Toggling is now a one-line experiment:
comment out the context-mode entry in the `extensions` list in
`home-manager/repo/pi.nix` and rebuild.

## Updating the pinned extensions later (keep this part in mind, then delete the file)

1. Bump versions in `home-manager/repo/pi-extensions-deps/package.json`.
2. Regenerate the lock: `npm install --package-lock-only` in that directory.
3. Set `npmDepsHash = lib.fakeHash` in `home-manager/repo/pi.nix`, rebuild,
   and paste the real hash from the error message.
