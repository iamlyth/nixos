# shellcheck shell=bash
set -euo pipefail

source_dir="${1:-}"
if [ -z "$source_dir" ] || [ ! -d "$source_dir" ] || [ -L "$source_dir" ]; then
  printf 'pi2: SSH runner is enabled, but the dedicated directory is missing or is a symlink: %s\n' \
    "$source_dir" >&2
  exit 1
fi
