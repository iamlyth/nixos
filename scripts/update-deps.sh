#!/usr/bin/env bash
# Update the manually pinned dependencies that `nix flake update` cannot
# reach. All pins live in home-manager/repo/pins.json; the .nix modules
# read them via importJSON and this script edits only the JSON (plus the
# package.json of managed npm dirs), so targets are DERIVED from the data.
# Adding a pin to pins.json, or a package to a managed npm dir, makes it
# updatable here with no script changes.
#
# Usage:
#   scripts/update-deps.sh --check           show current vs latest, change nothing
#   scripts/update-deps.sh all               update everything
#   scripts/update-deps.sh <target> [...]    update only the named targets
#   scripts/update-deps.sh --help            this text plus the current target list
#
# pins.json entry schema (the "type" field drives the behavior):
#   github-head     { owner, repo, rev, hash }             -> update to branch head
#   github-release  { owner, repo, rev, hash, version }    -> update to latest release tag
#   npm-deps        { dir, nixpkgs, npmDepsHash,           -> regenerate dir's lockfile and
#                     fetcherVersion?, managePackages? }      recompute npmDepsHash
# Optional on any entry: "note" (printed after updating it).
# npm-deps fields: "dir" is repo-relative; "nixpkgs" is the flake-input
# attrpath whose nixpkgs builds the deps (node ABI must match the consumer);
# "managePackages": true additionally exposes each dependency in dir's
# package.json as its own update target (bump to latest from the registry).
#
# Flake inputs are NOT handled here; use `nix flake update [input]`.
# nixpkgs-ollama stays deliberately frozen; see the comment in flake.nix.
#
# Requires: nix, git, curl, node + npm (present via the claude module).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PINS="$ROOT/home-manager/repo/pins.json"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- json helpers ------------------------------------------------------------

jget() { # jget FILE key [key...] -> value or empty
  node -e 'let v=require(process.argv[1]); for (const k of process.argv.slice(2)) v=v?.[k]; console.log(v ?? "");' "$@"
}

jset() { # jset FILE value key [key...]
  node -e '
    const fs = require("fs");
    const [file, value, ...keys] = process.argv.slice(1);
    const obj = JSON.parse(fs.readFileSync(file, "utf8"));
    let t = obj;
    const last = keys.pop();
    for (const k of keys) t = t[k];
    t[last] = value;
    fs.writeFileSync(file, JSON.stringify(obj, null, 2) + "\n");
  ' "$@"
}

# --- pin registry, derived from pins.json ------------------------------------

declare -A GH_MODE NPM_DIR NPM_DIRTY PKG_OWNER

load_pins() {
  while IFS=$'\t' read -r key type; do
    case "$type" in
      github-head)    GH_MODE[$key]=head ;;
      github-release) GH_MODE[$key]=release ;;
      npm-deps)
        NPM_DIR[$key]="$ROOT/$(jget "$PINS" "$key" dir)"
        if [ "$(jget "$PINS" "$key" managePackages)" = "true" ]; then
          while IFS= read -r pkg; do
            [ -n "$pkg" ] && PKG_OWNER[$pkg]=$key
          done < <(node -e 'console.log(Object.keys(require(process.argv[1]).dependencies || {}).join("\n"));' "${NPM_DIR[$key]}/package.json")
        fi
        ;;
      *) echo "pins.json: '$key' has unknown type '$type'" >&2; exit 1 ;;
    esac
  done < <(node -e 'for (const [k,v] of Object.entries(require(process.argv[1]))) console.log(`${k}\t${v.type}`);' "$PINS")
}

print_targets() {
  echo "Current targets (derived from pins.json):"
  local k
  for k in "${!GH_MODE[@]}"; do
    echo "  $k  [github ${GH_MODE[$k]}: $(jget "$PINS" "$k" owner)/$(jget "$PINS" "$k" repo)]"
  done
  for k in "${!NPM_DIR[@]}"; do
    echo "  $k  [npm-deps: regenerate lock + npmDepsHash]"
  done
  for k in "${!PKG_OWNER[@]}"; do
    echo "  $k  [npm package in ${PKG_OWNER[$k]}]"
  done
}

print_note() { # PIN_KEY
  local note
  note=$(jget "$PINS" "$1" note)
  [ -n "$note" ] && echo "  NOTE: $note"
  return 0
}

# --- github pins --------------------------------------------------------------

gh_api() { curl -fsSL -H "Accept: application/vnd.github+json" "https://api.github.com/$1"; }
gh_json() { node -pe 'JSON.parse(require("fs").readFileSync(0))'"$1"; }

latest_github_rev() { # PIN_KEY -> "rev[ tag]"
  local key="$1" owner repo tag
  owner=$(jget "$PINS" "$key" owner); repo=$(jget "$PINS" "$key" repo)
  if [ "${GH_MODE[$key]}" = release ]; then
    tag=$(gh_api "repos/$owner/$repo/releases/latest" | gh_json .tag_name)
    echo "$(gh_api "repos/$owner/$repo/commits/$tag" | gh_json .sha) $tag"
  else
    gh_api "repos/$owner/$repo/commits/HEAD" | gh_json .sha
  fi
}

update_github_pin() { # PIN_KEY
  local key="$1" cur rev tag hash
  cur=$(jget "$PINS" "$key" rev)
  read -r rev tag < <(latest_github_rev "$key")
  if [ "$rev" = "$cur" ]; then
    echo "$key: up to date (${cur:0:12})"
    return
  fi
  echo "$key: ${cur:0:12} -> ${rev:0:12}${tag:+ ($tag)}"
  hash=$(nix hash convert --hash-algo sha256 --to sri \
    "$(nix-prefetch-url --unpack "https://github.com/$(jget "$PINS" "$key" owner)/$(jget "$PINS" "$key" repo)/archive/$rev.tar.gz" 2>/dev/null)")
  jset "$PINS" "$rev" "$key" rev
  jset "$PINS" "$hash" "$key" hash
  [ -n "${tag:-}" ] && jset "$PINS" "${tag#v}" "$key" version
  print_note "$key"
}

check_github_pin() { # PIN_KEY
  local key="$1" cur rev _tag
  cur=$(jget "$PINS" "$key" rev)
  read -r rev _tag < <(latest_github_rev "$key")
  if [ "$rev" = "$cur" ]; then
    echo "$key: up to date (${cur:0:12})"
  else
    echo "$key: ${cur:0:12} -> ${rev:0:12} available"
  fi
}

# --- npm-deps pins ------------------------------------------------------------

update_npm_pkg() { # PACKAGE_NAME
  local pkg="$1" owner="${PKG_OWNER[$1]}" cur latest
  cur=$(jget "${NPM_DIR[$owner]}/package.json" dependencies "$pkg")
  latest=$(npm view "$pkg" version)
  if [ "$cur" = "$latest" ]; then
    echo "$pkg: up to date ($cur)"
    return
  fi
  echo "$pkg: $cur -> $latest"
  jset "${NPM_DIR[$owner]}/package.json" "$latest" dependencies "$pkg"
  NPM_DIRTY[$owner]=1
}

check_npm_pkg() { # PACKAGE_NAME
  local pkg="$1" cur latest
  cur=$(jget "${NPM_DIR[${PKG_OWNER[$pkg]}]}/package.json" dependencies "$pkg")
  latest=$(npm view "$pkg" version)
  if [ "$cur" = "$latest" ]; then
    echo "$pkg: up to date ($cur)"
  else
    echo "$pkg: $cur -> $latest available"
  fi
}

# npm lockfiles can carry entries without integrity (seen with peer-induced
# nested duplicates); fetchNpmDeps rejects those. Backfill from the registry.
fix_lock_integrity() { # FILE
  LOCKFILE="$1" node --input-type=module - <<'EOF'
import fs from 'fs';
const p = process.env.LOCKFILE;
const lock = JSON.parse(fs.readFileSync(p, 'utf8'));
let n = 0;
for (const [k, v] of Object.entries(lock.packages)) {
  if (!k || v.integrity || v.link || !v.resolved) continue;
  const name = k.split('node_modules/').pop();
  const meta = await (await fetch(`https://registry.npmjs.org/${name}/${v.version}`)).json();
  v.integrity = meta.dist.integrity;
  n++;
}
fs.writeFileSync(p, JSON.stringify(lock, null, 2) + '\n');
console.log(`  backfilled integrity on ${n} lock entries`);
EOF
}

# Hash-check derivation generated from the pin's dir/nixpkgs/fetcherVersion
# fields; the consuming .nix module must build its deps the same way.
write_npm_deps_expr() { # PIN_KEY -> expr file path (with @HASH@ placeholder)
  local key="$1" nixpkgs fetcher
  nixpkgs=$(jget "$PINS" "$key" nixpkgs)
  fetcher=$(jget "$PINS" "$key" fetcherVersion)
  cat > "$TMP/$key.nix" <<EOF
let
  flake = builtins.getFlake "git+file://$ROOT";
  pkgs = flake.inputs.$nixpkgs.legacyPackages.\${builtins.currentSystem};
in pkgs.buildNpmPackage {
  pname = "$key";
  version = "hash-check";
  src = ${NPM_DIR[$key]};
  npmDepsHash = "@HASH@";
  ${fetcher:+npmDepsFetcherVersion = $fetcher;}
  nativeBuildInputs = [ pkgs.python3 ];
  dontBuild = true;
  installPhase = "mkdir -p \$out; cp -r node_modules \$out/";
}
EOF
  echo "$TMP/$key.nix"
}

regen_npm_deps() { # PIN_KEY
  local key="$1" expr out hash
  echo "$key: regenerating lock and npmDepsHash..."
  (cd "${NPM_DIR[$key]}" && rm -f package-lock.json && npm install --package-lock-only --ignore-scripts >/dev/null 2>&1)
  fix_lock_integrity "${NPM_DIR[$key]}/package-lock.json"
  expr=$(write_npm_deps_expr "$key")
  sed "s|@HASH@|sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=|" "$expr" > "$TMP/fake.nix"
  out=$(nix build --impure --no-link --file "$TMP/fake.nix" 2>&1 || true)
  hash=$(printf '%s\n' "$out" | sed -n 's/.*got: *//p' | head -n1)
  if [ -z "$hash" ]; then
    printf '%s\n' "$out" >&2
    echo "ERROR: could not extract npmDepsHash for $key" >&2
    return 1
  fi
  jset "$PINS" "$hash" "$key" npmDepsHash
  echo "  npmDepsHash: $hash"
  sed "s|@HASH@|$hash|" "$expr" > "$TMP/real.nix"
  nix build --impure --no-link --file "$TMP/real.nix"
  echo "  verify build: OK"
  print_note "$key"
}

# --- main ---------------------------------------------------------------------

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
  echo
  print_targets
}

load_pins

[ $# -eq 0 ] && { usage; exit 1; }
case "$1" in -h|--help|help) usage; exit 0 ;; esac

if [ "$1" = --check ]; then
  for k in "${!GH_MODE[@]}"; do check_github_pin "$k"; done
  for k in "${!PKG_OWNER[@]}"; do check_npm_pkg "$k"; done
  for k in "${!NPM_DIR[@]}"; do echo "$k: hash-only target (regenerates on demand or when its packages update)"; done
  exit 0
fi

targets=("$@")
if [ "${targets[0]}" = all ]; then
  targets=("${!GH_MODE[@]}" "${!PKG_OWNER[@]}" "${!NPM_DIR[@]}")
fi

for t in "${targets[@]}"; do
  if [ -n "${GH_MODE[$t]:-}" ]; then
    update_github_pin "$t"
  elif [ -n "${PKG_OWNER[$t]:-}" ]; then
    update_npm_pkg "$t"
  elif [ -n "${NPM_DIR[$t]:-}" ]; then
    NPM_DIRTY[$t]=1
  else
    echo "unknown target: $t" >&2
    echo >&2
    print_targets >&2
    exit 1
  fi
done

for k in "${!NPM_DIRTY[@]}"; do regen_npm_deps "$k"; done

echo
echo "Done. Review with: git diff"
echo "Then rebuild the affected host(s) to verify."
