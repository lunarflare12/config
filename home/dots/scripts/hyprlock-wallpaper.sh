#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/.wall"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/aurora/wallpaper"
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/aurora/current-wallpaper"
CURRENT_FILE="$WALL_DIR/.current"
FALLBACK="/etc/profiles/per-user/$USER/share/sddm/themes/glyph/assets/images/background.jpg"

for candidate in "$STATE_FILE" "$CACHE_FILE"; do
  if [ -s "$candidate" ]; then
    path=$(tr -d '\n' < "$candidate")
    if [ -f "$path" ]; then
      printf '%s\n' "$path"
      exit 0
    fi
  fi
done

if [ -s "$CURRENT_FILE" ]; then
  name=$(tr -d '[:space:]' < "$CURRENT_FILE")
  if [ -f "$WALL_DIR/$name" ]; then
    printf '%s\n' "$WALL_DIR/$name"
    exit 0
  fi
  if [ -f "$HOME/Wallpapers/$name" ]; then
    printf '%s\n' "$HOME/Wallpapers/$name"
    exit 0
  fi
fi

first=$(find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) ! -name ".*" 2>/dev/null | head -n 1)
if [ -n "$first" ]; then
  printf '%s\n' "$first"
  exit 0
fi

if [ -f "$FALLBACK" ]; then
  printf '%s\n' "$FALLBACK"
  exit 0
fi

printf '%s\n' "/run/current-system/sw/share/sddm/themes/glyph/assets/images/background.jpg"
