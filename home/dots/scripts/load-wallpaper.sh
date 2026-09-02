#!/bin/bash
set -euo pipefail

WALL_DIR="$HOME/.wall"
CURRENT_FILE="$WALL_DIR/.current"
DEFAULT_FILE="$WALL_DIR/.current.default"

if [ ! -s "$CURRENT_FILE" ]; then
  if [ ! -s "$DEFAULT_FILE" ]; then
    echo "No default wallpaper configured" >&2
    exit 1
  fi
  cp "$DEFAULT_FILE" "$CURRENT_FILE"
fi

wait_for_swww() {
  local attempt=0
  while ! pgrep -x swww-daemon >/dev/null && [ "$attempt" -lt 10 ]; do
    sleep 0.5
    attempt=$((attempt + 1))
  done
}

load_wallpaper() {
  local saved_name
  saved_name=$(cat "$CURRENT_FILE")
  local wallpaper="$WALL_DIR/$saved_name"

  if [ ! -f "$wallpaper" ]; then
    echo "Wallpaper not found: $wallpaper" >&2
    exit 1
  fi

  swww img "$wallpaper" --transition-type grow --transition-duration 1.4 --transition-fps 60
}

wait_for_swww
load_wallpaper
