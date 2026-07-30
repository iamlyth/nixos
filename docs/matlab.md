# MATLAB (imperative, per-repo environments)

MATLAB is proprietary and not in nixpkgs, and it expects a standard FHS
filesystem that NixOS doesn't provide. So it is installed **imperatively** into a
plain directory and launched through an FHS wrapper.

Nothing about MATLAB lives in this NixOS config — no module, no `nixos-rebuild`.
The only system-side requirements are already satisfied here:

- `nix-command` + `flakes` — enabled in `hosts/wixomOS.nix`.
- `direnv` + `nix-direnv` — enabled in `home-manager/repo/zsh.nix`.

The reusable launcher template lives **outside** this repo at
`~/matlab-envs/template/` (`flake.nix`, `.envrc`, `README.md`). Each project
gets its own copy pinned to a MATLAB version + native deps.

## Two directories, don't confuse them

| Directory | What it holds | Size |
|---|---|---|
| `~/matlab-envs/template/` | The Nix launcher template — tiny text files. *Not MATLAB.* | KBs |
| `/opt/MATLAB/<release>/` | The actual MATLAB install — app + toolboxes. | GBs |

## One-time: install a MATLAB version

1. Download the **Linux** installer `.zip` for the release (e.g. R2025a) from your
   MathWorks account and unzip it.
2. Create the install dir once, owned by you so the installer needs no root:
   ```bash
   sudo install -d -o "$USER" -g users /opt/MATLAB
   ```
3. `cd` into the unzipped installer directory.
4. Enter an FHS shell that has everything the installer needs:
   ```bash
   nix run gitlab:doronbehar/nix-matlab#matlab-shell
   ```
5. Inside that shell, run the GUI installer:
   ```bash
   ./install
   ```
   - Sign in, then set the install folder to **`/opt/MATLAB/R2025a`**.
   - Select the toolboxes you need (Simulink, Simulink Coder, MATLAB Coder,
     Simulink PLC Coder, …).
   - Finish, then `exit` the shell.

Repeat with a different folder (`/opt/MATLAB/R2024b`) for another version — they
coexist. Uninstall a version = delete its directory.

## Per-repo usage

1. Copy the template files into the repo:
   ```bash
   cp ~/matlab-envs/template/{flake.nix,.envrc,setup-local-ignore.sh} .
   ```
2. Locally ignore them (so they never touch the company's tracked files — see
   the section below for how this works):
   ```bash
   ./setup-local-ignore.sh
   ```
3. Edit the `EDIT PER REPO` block in `flake.nix`:
   - `matlabRelease` — which version this repo uses.
   - `extraPkgs` — any native libs/tools the repo's toolboxes need
     (`hdf5`, `ffmpeg`, `cmake`, …). Leave empty for pure-MATLAB repos.
4. In the repo:
   ```bash
   direnv allow
   ```
   From now on, `cd` into the repo → MATLAB env auto-loads. Launch with
   `matlab-R2025a` (or `nix run` for the GUI). `cd` out → it unloads.

## Do I need to commit the flake into the company repo?

**No.** The per-repo `flake.nix` is a *standalone* flake — it has nothing to do
with this NixOS `flake.nix`, and your NixOS config never moves. You have three
ways to attach it to a company repo without polluting their tracked files:

1. **Local git exclude (recommended).** Drop `flake.nix` + `.envrc` into the
   repo working tree, then run the bundled helper to exclude them locally so
   they never get committed or show up in `git status`:
   ```bash
   ./setup-local-ignore.sh
   ```
   It writes `/flake.nix`, `/flake.lock`, `/.envrc`, `/.direnv/`, and itself to
   the repo's `info/exclude`, which is per-checkout and never committed or
   pushed. It's idempotent, and resolves the exclude path via
   `git rev-parse --git-path`, so it works in plain clones *and* `git worktree`
   checkouts (one run covers every worktree of the same repo). The equivalent by
   hand:
   ```bash
   printf '/flake.nix\n/flake.lock\n/.envrc\n/.direnv/\n' >> .git/info/exclude
   ```

2. **Keep the flake outside the repo.** Store it at e.g.
   `~/matlab-envs/<projectname>/flake.nix` and point the repo's `.envrc` at it:
   ```bash
   # .envrc
   use flake ~/matlab-envs/<projectname>
   ```
   (You can still local-exclude the one-line `.envrc`.)

3. **Commit it** — only if the team also uses this NixOS/nix-matlab setup and
   wants it shared. Usually not the case, so prefer option 1 or 2.

## Notes

- Simulink is supported (the FHS wrapper sets `QT_QPA_PLATFORM=xcb` and pulls in
  `mesa` / `libxkbcommon`, which Simulink needs).
- Simulink PLC Coder runs for code generation; the downstream PLC vendor IDEs
  (CODESYS, TIA Portal, Studio 5000) are separate Windows tools.
- `mex` works out of the box — `gcc`/`gfortran` and MATLAB's headers are wired in.
- MATLAB pins "supported" compiler versions per release; a mismatch is usually a
  harmless warning. If a toolbox insists, add the matching `gccN` to `extraPkgs`.
