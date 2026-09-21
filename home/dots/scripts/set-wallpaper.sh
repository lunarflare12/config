#!/usr/bin/env bash
set -euo pipefail

wallpaper="${1:?Usage: set-wallpaper.sh /path/to/wallpaper}"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/aurora"
state_file="$state_dir/wallpaper"
cache_file="${XDG_CACHE_HOME:-$HOME/.cache}/aurora/current-wallpaper"
current_file="$HOME/Wallpapers/.current"

if [ ! -f "$wallpaper" ]; then
  printf 'Wallpaper not found: %s\n' "$wallpaper" >&2
  exit 1
fi

wallpaper=$(readlink -f "$wallpaper")

mkdir -p "$state_dir" "$(dirname "$cache_file")" "$HOME/Wallpapers"
printf '%s\n' "$wallpaper" > "$state_file"
printf '%s\n' "$wallpaper" > "$cache_file"
chmod u+w "$state_file" "$cache_file" 2>/dev/null || true

if [ -e "$current_file" ]; then
  chmod u+w "$current_file" 2>/dev/null || true
fi
printf '%s\n' "$(basename "$wallpaper")" > "$current_file" 2>/dev/null || true

awww img "$wallpaper" --transition-type fade --transition-fps 60 --transition-step 30
