#!/bin/bash
set -euo pipefail

WALL_DIR="$HOME/.wall"
CURRENT_FILE="$WALL_DIR/.current"
TRANSITIONS=("grow" "wave")

get_random_wallpaper() {
  local current_wallpaper=""
  if [ -f "$CURRENT_FILE" ] && [ -s "$CURRENT_FILE" ]; then
    current_wallpaper=$(cat "$CURRENT_FILE")
  fi

  local all_wallpapers
  all_wallpapers=$(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) ! -name ".*")

  if [ -z "$all_wallpapers" ]; then
    return 1
  fi

  echo "$all_wallpapers" | grep -v "$current_wallpaper" | shuf -n 1 || echo "$all_wallpapers" | shuf -n 1
}

wallpaper="${1:-}"
if [ -n "$wallpaper" ]; then
  case "$wallpaper" in
    "$WALL_DIR"/*) ;;
    *) wallpaper="$WALL_DIR/$wallpaper" ;;
  esac
else
  wallpaper=$(get_random_wallpaper)
fi

if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
  notify-send -i dialog-error "Error" "No wallpapers found in $WALL_DIR" -t 3000
  exit 1
fi

transition="${TRANSITIONS[$RANDOM % ${#TRANSITIONS[@]}]}"
awww img "$wallpaper" --transition-type "$transition" --transition-duration 1.2 --transition-fps 60
echo "$(basename "$wallpaper")" > "$CURRENT_FILE"
notify-send -i "$wallpaper" "Wallpaper Changed" "$(basename "$wallpaper")" -t 3000
