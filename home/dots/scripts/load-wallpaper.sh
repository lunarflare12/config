#!/usr/bin/env bash
set -euo pipefail

WALL_DIR="$HOME/Wallpapers"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/aurora/wallpaper"
CACHE_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/aurora/current-wallpaper"

resolve_wallpaper() {
  local candidate
  for candidate in "$STATE_FILE" "$CACHE_FILE"; do
    if [ -s "$candidate" ]; then
      local path
      path=$(tr -d '\n' < "$candidate")
      if [ -f "$path" ]; then
        case "$path" in
          "$WALL_DIR"/*)
            printf '%s\n' "$path"
            return 0
            ;;
        esac
        local name
        name=$(basename "$path")
        if [ -f "$WALL_DIR/$name" ]; then
          printf '%s\n' "$WALL_DIR/$name"
          return 0
        fi
      fi
    fi
  done

  find -L "$WALL_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.webp" \) ! -name ".*" 2>/dev/null | sort | head -n 1
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
  echo "No wallpaper found in ~/Wallpapers" >&2
  exit 1
fi

awww img "$wallpaper" --transition-type none
