#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/.wall"
CURRENT_FILE="$WALL_DIR/.current"
FALLBACK="/etc/profiles/per-user/$USER/share/sddm/themes/glyph/assets/images/background.jpg"

if [ -s "$CURRENT_FILE" ]; then
  name=$(tr -d '[:space:]' < "$CURRENT_FILE")
  if [ -f "$WALL_DIR/$name" ]; then
    printf '%s\n' "$WALL_DIR/$name"
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
