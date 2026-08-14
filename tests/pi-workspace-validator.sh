#!/usr/bin/env bash
# shellcheck disable=SC2016 # Positional parameters intentionally expand in bash -c.
set -euo pipefail

validator="$(command -v pi-validate-workspace)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export HOME="$tmp/home"
mkdir -p "$HOME" "$tmp/approved/project/subdir" "$tmp/outside/project"

git -C "$tmp/approved/project" init -q
git -C "$tmp/outside/project" init -q

expect_failure() {
  expected="$1"
  shift
  if "$@" >"$tmp/stdout" 2>"$tmp/stderr"; then
    printf 'expected failure: %s\n' "$expected" >&2
    exit 1
  fi
  grep -F -- "$expected" "$tmp/stderr" >/dev/null
}

actual="$(cd "$tmp/approved/project/subdir" && "$validator")"
[ "$actual" = "$(realpath "$tmp/approved/project")" ]
actual="$(cd "$tmp/approved/project/subdir" && "$validator" --root "$tmp/approved")"
[ "$actual" = "$(realpath "$tmp/approved/project")" ]
actual="$(cd "$tmp/approved/project/subdir" && "$validator" --project "$tmp/approved/project")"
[ "$actual" = "$(realpath "$tmp/approved/project")" ]
expect_failure "outside the approved workspace roots and projects" \
  bash -c 'cd "$1" && exec "$2" --root "$3"' _ "$tmp/outside/project" "$validator" "$tmp/approved"
expect_failure "outside the approved workspace roots and projects" \
  bash -c 'cd "$1" && exec "$2" --root "$3"' _ "$tmp/approved/project" "$validator" "$tmp/approved/project"
expect_failure "outside the approved workspace roots and projects" \
  bash -c 'cd "$1" && exec "$2" --project "$3"' _ "$tmp/outside/project" "$validator" "$tmp/approved/project"
expect_failure "approved workspace project does not exist" \
  bash -c 'cd "$1" && exec "$2" --project "$3"' _ "$tmp/approved/project" "$validator" "$tmp/missing"
expect_failure "refusing sensitive launch directory: /" \
  bash -c 'cd / && exec "$1"' _ "$validator"
expect_failure "refusing sensitive launch directory" \
  bash -c 'cd "$1" && exec "$2"' _ "$HOME" "$validator"

ln -s "$tmp/outside/project" "$tmp/approved/escape"
expect_failure "outside the approved workspace roots and projects" \
  bash -c 'cd -L "$1" && exec "$2" --root "$3"' _ "$tmp/approved/escape" "$validator" "$tmp/approved"

git -C "$tmp/approved/project" \
  -c user.name=test -c user.email=test.invalid \
  commit --allow-empty -q -m initial
git -C "$tmp/approved/project" worktree add -q "$tmp/approved/linked"
expect_failure "Git metadata is outside the project" \
  bash -c 'cd "$1" && exec "$2" --root "$3"' _ "$tmp/approved/linked" "$validator" "$tmp/approved"

printf 'pi workspace policy tests passed\n'
