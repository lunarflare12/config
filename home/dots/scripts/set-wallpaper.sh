#!/bin/bash
set -euo pipefail

wallpaper="${1:?Usage: set-wallpaper.sh /path/to/wallpaper}"
wall_dir="$HOME/.wall"
current_file="$wall_dir/.current"

if [ ! -f "$wallpaper" ]; then
  printf 'Wallpaper not found: %s\n' "$wallpaper" >&2
  exit 1
fi

swww img "$wallpaper" --transition-type grow --transition-duration 1.4 --transition-fps 60
printf '%s\n' "$(basename "$wallpaper")" > "$current_file"
notify-send -i "$wallpaper" "Wallpaper Changed" "$(basename "$wallpaper")" -t 3000
