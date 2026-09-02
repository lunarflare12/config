#!/bin/bash
set -euo pipefail

WALL_DIR="$HOME/.wall"
CURRENT_FILE="$WALL_DIR/.current"
DEFAULT_FILE="$WALL_DIR/.current.default"

if [ ! -s "$CURRENT_FILE" ]; then
  if [ -s "$DEFAULT_FILE" ]; then
    cp "$DEFAULT_FILE" "$CURRENT_FILE"
  else
    first=$(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) ! -name ".*" | head -n 1)
    if [ -n "$first" ]; then
      basename "$first" > "$CURRENT_FILE"
    fi
  fi
fi

wait_for_swww() {
  local attempt=0
  while [ "$attempt" -lt 30 ]; do
    if swww query >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
    attempt=$((attempt + 1))
  done
  return 1
}

load_wallpaper() {
  local saved_name
  saved_name=$(tr -d '[:space:]' < "$CURRENT_FILE")
  local wallpaper="$WALL_DIR/$saved_name"

  if [ ! -f "$wallpaper" ]; then
    wallpaper=$(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) ! -name ".*" | head -n 1)
  fi

  if [ -z "$wallpaper" ] || [ ! -f "$wallpaper" ]; then
    echo "No wallpaper found in $WALL_DIR" >&2
    exit 1
  fi

  swww img "$wallpaper" --transition-type none
}

wait_for_swww
load_wallpaper
