#!/usr/bin/env bash
set -euo pipefail

dir="${HOME}/Pictures/wallpapers"
state="${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper/current"
default="${dir}/36.png"

pick="$default"
if [[ -f "$state" ]]; then
  saved=$(<"$state")
  if [[ -f "$saved" ]]; then
    pick="$saved"
  fi
fi

if [[ ! -f "$pick" ]]; then
  echo "swww-restore: no wallpaper at ${pick}" >&2
  exit 0
fi

for _ in $(seq 1 50); do
  if awww query &>/dev/null; then
    break
  fi
  sleep 0.1
done

awww img "$pick" --transition-type none
mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
printf '%s\n' "$pick" >"$state"
