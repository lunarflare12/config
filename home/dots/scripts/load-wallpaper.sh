#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/.wall"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/aurora/wallpaper"
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/aurora/current-wallpaper"
CURRENT_FILE="$WALL_DIR/.current"
DEFAULT_FILE="$WALL_DIR/.current.default"

resolve_wallpaper() {
  local candidate
  for candidate in "$STATE_FILE" "$CACHE_FILE"; do
    if [ -s "$candidate" ]; then
      local path
      path=$(tr -d '\n' < "$candidate")
      if [ -f "$path" ]; then
        printf '%s\n' "$path"
        return 0
      fi
    fi
  done

  if [ -s "$CURRENT_FILE" ]; then
    local name
    name=$(tr -d '[:space:]' < "$CURRENT_FILE")
    if [ -f "$WALL_DIR/$name" ]; then
      printf '%s\n' "$WALL_DIR/$name"
      return 0
    fi
    if [ -f "$HOME/Wallpapers/$name" ]; then
      printf '%s\n' "$HOME/Wallpapers/$name"
      return 0
    fi
  fi

  if [ -s "$DEFAULT_FILE" ]; then
    local name
    name=$(tr -d '[:space:]' < "$DEFAULT_FILE")
    if [ -f "$WALL_DIR/$name" ]; then
      printf '%s\n' "$WALL_DIR/$name"
      return 0
    fi
  fi

  find -L "$WALL_DIR" "$HOME/Wallpapers" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) ! -name ".*" 2>/dev/null | head -n 1
}

wait_for_awww() {
  local attempt=0
  while [ "$attempt" -lt 30 ]; do
    if awww query >/dev/null 2>&1; then
      return 0
    fi
    sleep 0.2
    attempt=$((attempt + 1))
  done
  echo "awww is not ready yet" >&2
  exit 0
}

wait_for_awww

wallpaper=$(resolve_wallpaper || true)
if [ -z "${wallpaper:-}" ] || [ ! -f "$wallpaper" ]; then
  echo "No wallpaper found" >&2
  exit 1
fi

awww img "$wallpaper" --transition-type none
