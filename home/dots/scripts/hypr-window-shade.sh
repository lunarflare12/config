#!/usr/bin/env bash
# Load HyprWindowShade so liixini open/close GLSL can run on desktop windows.
# Games must never get the plugin — it paints every frame and breaks the cursor.
set -euo pipefail

HYPRCTL="${HYPRCTL:-hyprctl}"
HOME_DIR="${HOME:-/home/dd}"
CFG="${XDG_CONFIG_HOME:-$HOME_DIR/.config}/hypr"
SHADER_ROOT="$CFG/shaders/liixini"
CURRENT_FILE="$SHADER_ROOT/CURRENT"
DIR_FILE="$CFG/hypr-window-shade-dir"

resolve_so() {
  if [ -f "$DIR_FILE" ]; then
    dir=$(tr -d '\n' <"$DIR_FILE")
    for cand in "$dir/lib/libHyprWindowShade.so" "$dir/lib/HyprWindowShade.so"; do
      if [ -f "$cand" ]; then
        printf '%s\n' "$cand"
        return 0
      fi
    done
  fi
  for cand in /nix/store/*HyprWindowShade*/lib/libHyprWindowShade.so; do
    if [ -f "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

plugin_loaded() {
  "$HYPRCTL" plugin list 2>/dev/null | grep -qi 'HyprWindowShade'
}

ow_running() {
  "$HYPRCTL" clients -j 2>/dev/null | grep -q '"class": "steam_app_2357570"' && return 0
  pgrep -x Overwatch.exe >/dev/null 2>&1
}

unload() {
  local so
  so=$(resolve_so || true)
  [ -n "$so" ] || return 0
  "$HYPRCTL" plugin unload "$so" >/dev/null 2>&1 || true
}

case "${1:-load}" in
load | reload)
  # Never shade while Overwatch is up — leftover tags + per-frame GLSL = lag.
  if ow_running; then
    unload
    exit 0
  fi
  so=$(resolve_so) || {
    echo "hypr-window-shade: plugin .so not found (rebuild home-manager)" >&2
    exit 1
  }
  if ! plugin_loaded; then
    "$HYPRCTL" plugin load "$so" >/dev/null
  fi
  if [ -n "${2:-}" ]; then
    printf '%s\n' "$2" >"$CURRENT_FILE"
    "$HYPRCTL" reload >/dev/null
  fi
  ;;
unload | unload-game)
  unload
  ;;
set)
  exec "$0" load "${2:?effect name required}"
  ;;
list)
  find "$SHADER_ROOT" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
  ;;
current)
  if [ -f "$CURRENT_FILE" ]; then
    tr -d '[:space:]' <"$CURRENT_FILE"
    echo
  else
    echo crosshatch
  fi
  ;;
*)
  echo "usage: $0 load|reload|unload|set <effect>|list|current" >&2
  exit 2
  ;;
esac
