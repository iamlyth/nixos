#!/usr/bin/env bash
set -euo pipefail

validator="$(command -v pi-validate-ssh-runner)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

expect_failure() {
  if "$@" >"$tmp/stdout" 2>"$tmp/stderr"; then
    echo "expected SSH runner validator failure" >&2
    exit 1
  fi
  grep -F "dedicated directory is missing or is a symlink" "$tmp/stderr" >/dev/null
}

expect_failure "$validator" "$tmp/missing"
mkdir "$tmp/runner"
"$validator" "$tmp/runner"
ln -s "$tmp/runner" "$tmp/runner-link"
expect_failure "$validator" "$tmp/runner-link"

printf 'pi SSH runner source tests passed\n'
