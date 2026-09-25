#!/usr/bin/env bash
# Pull this flake from git, then rebuild. Local edits are left alone.
set -uo pipefail

notify() {
  local urgency=$1
  shift
  notify-send -a Aurora -u "$urgency" -- "System update" "$*" >/dev/null 2>&1 || true
}

repo="${HOME}/Documents/projects/config"
cd "$repo" || {
  printf 'Could not open %s\n' "$repo"
  notify critical "Could not open $repo"
  printf '\nPress enter to close.\n'
  read -r _
  exit 1
}

before=$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')

printf '==> git pull --ff-only\n'
if git pull --ff-only; then
  after=$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')
  if [[ $before == "$after" ]]; then
    pull_msg="Already up to date ($after)."
  else
    pull_msg="Pulled ${before} → ${after}."
  fi
else
  after=$before
  pull_msg="Git pull skipped (could not fast-forward)."
  printf '\n%s\n' "$pull_msg"
fi

printf '\n==> nixos-rebuild switch --flake %s#nixos\n' "$repo"
if sudo nixos-rebuild switch --flake "$repo#nixos"; then
  printf '\nDone.\n'
  notify normal "${pull_msg} Rebuild finished."
  printf '\nPress enter to close.\n'
  read -r _
  exit 0
fi

printf '\nRebuild failed.\n'
notify critical "${pull_msg} Rebuild failed."
printf '\nPress enter to close.\n'
read -r _
exit 1
