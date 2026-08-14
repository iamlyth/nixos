# shellcheck shell=bash
set -euo pipefail

fail() {
  printf 'pi jail: %s\n' "$*" >&2
  exit 1
}

is_sensitive_path() {
  case "$1" in
    / | /boot | /boot/* | /dev | /dev/* | /etc | /etc/* | /nix | /nix/* | \
      /proc | /proc/* | /root | /root/* | /run | /run/* | /sys | /sys/* | \
      /tmp | /tmp/* | /usr | /usr/* | /var | /var/* | /mnt | /mnt/* | \
      /media | /media/* | /opt | /opt/* | /srv | /srv/*)
      return 0
      ;;
  esac

  if [ -n "${PI_JAIL_HOST_HOME:-${HOME:-}}" ]; then
    home_path="$(realpath -m -- "${PI_JAIL_HOST_HOME:-$HOME}")"
    case "$1" in
      "$home_path" | "$home_path"/.cache | "$home_path"/.cache/* | \
        "$home_path"/.config | "$home_path"/.config/* | \
        "$home_path"/.gnupg | "$home_path"/.gnupg/* | \
        "$home_path"/.local | "$home_path"/.local/* | \
        "$home_path"/.password-store | "$home_path"/.password-store/* | \
        "$home_path"/.ssh | "$home_path"/.ssh/*)
        return 0
        ;;
    esac
  fi

  return 1
}

approved_roots=()
approved_projects=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --root | --project)
      [ "$#" -ge 2 ] || fail "missing path after $1"
      if [ "$1" = "--root" ]; then
        approved_roots+=("$2")
      else
        approved_projects+=("$2")
      fi
      shift 2
      ;;
    *) fail "unknown workspace policy argument: $1" ;;
  esac
done

launch_dir="$(realpath -e -- "$PWD" 2>/dev/null)" || \
  fail "cannot canonicalize launch directory: $PWD"
[ -d "$launch_dir" ] || fail "launch path is not a directory: $launch_dir"
is_sensitive_path "$launch_dir" && \
  fail "refusing sensitive launch directory: $launch_dir"

project_dir="$(git -C "$launch_dir" rev-parse --show-toplevel 2>/dev/null)" || \
  fail "launch directory is not inside a Git worktree: $launch_dir"
project_dir="$(realpath -e -- "$project_dir" 2>/dev/null)" || \
  fail "cannot canonicalize Git worktree root: $project_dir"
[ -d "$project_dir" ] || fail "Git worktree root is not a directory: $project_dir"
is_sensitive_path "$project_dir" && \
  fail "refusing sensitive Git worktree root: $project_dir"

# Mounting the project at a stable destination changes its absolute path. A
# linked worktree or submodule whose gitdir lives elsewhere would either break
# inside the jail or require exposing metadata outside the project, so reject
# it instead of broadening the bind boundary.
git_common_dir="$(git -C "$project_dir" rev-parse --git-common-dir 2>/dev/null)" || \
  fail "cannot resolve Git metadata for: $project_dir"
case "$git_common_dir" in
  /*) ;;
  *) git_common_dir="$project_dir/$git_common_dir" ;;
esac
git_common_dir="$(realpath -e -- "$git_common_dir" 2>/dev/null)" || \
  fail "cannot canonicalize Git metadata: $git_common_dir"
case "$git_common_dir" in
  "$project_dir" | "$project_dir"/*) ;;
  *) fail "Git metadata is outside the project (linked worktrees and submodules are unsupported): $git_common_dir" ;;
esac

case "$launch_dir" in
  "$project_dir" | "$project_dir"/*) ;;
  *) fail "canonical launch directory escaped its Git worktree: $launch_dir" ;;
esac

# With no allowlist, any non-sensitive canonical Git worktree is valid. If at
# least one root or project is configured, those entries become a restrictive
# allowlist.
approved=true
if [ "${#approved_roots[@]}" -gt 0 ] || [ "${#approved_projects[@]}" -gt 0 ]; then
  approved=false
fi

for configured_root in "${approved_roots[@]}"; do
  approved_root="$(realpath -e -- "$configured_root" 2>/dev/null)" || \
    fail "approved workspace root does not exist: $configured_root"
  [ -d "$approved_root" ] || \
    fail "approved workspace root is not a directory: $configured_root"
  is_sensitive_path "$approved_root" && \
    fail "approved workspace root is sensitive: $approved_root"

  # A root is only a container for projects; never expose the root itself.
  case "$project_dir" in
    "$approved_root"/*) approved=true ;;
  esac
done

for configured_project in "${approved_projects[@]}"; do
  approved_project="$(realpath -e -- "$configured_project" 2>/dev/null)" || \
    fail "approved workspace project does not exist: $configured_project"
  [ -d "$approved_project" ] || \
    fail "approved workspace project is not a directory: $configured_project"
  is_sensitive_path "$approved_project" && \
    fail "approved workspace project is sensitive: $approved_project"
  [ "$project_dir" = "$approved_project" ] && approved=true
done

$approved || \
  fail "Git worktree is outside the approved workspace roots and projects: $project_dir"

printf '%s\n' "$project_dir"
