#!/usr/bin/env bash
set -euo pipefail

# grim + satty for a region already picked in Quickshell.
# usage: screenshot.sh X Y W H

if [[ $# -ne 4 ]]; then
  exit 1
fi

x=$1 y=$2 w=$3 h=$4
[[ "$w" -ge 8 && "$h" -ge 8 ]] || exit 1

SCREENSHOT_DIR="${HYPRSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$SCREENSHOT_DIR"
SCREENSHOT_PATH="$SCREENSHOT_DIR/screenshot_$(date +"%Y-%m-%d_%H-%M-%S").png"

grim -c -g "${x},${y} ${w}x${h}" "$SCREENSHOT_PATH"
wl-copy -t image/png <"$SCREENSHOT_PATH" >/dev/null 2>&1 || true

for share in "${HOME}/.nix-profile/share" "/etc/profiles/per-user/${USER}/share"; do
  if [[ -d "${share}/icons/Adwaita" ]]; then
    export XDG_DATA_DIRS="${share}:${XDG_DATA_DIRS:-/usr/share}"
    break
  fi
done
if [[ ! -d "${XDG_DATA_DIRS%%:*}/icons/Adwaita" ]]; then
  share=$(ls -d /nix/store/*-adwaita-icon-theme-*/share 2>/dev/null | tail -n 1 || true)
  if [[ -n "$share" && -d "${share}/icons/Adwaita" ]]; then
    export XDG_DATA_DIRS="${share}:${XDG_DATA_DIRS:-/usr/share}"
  fi
fi
export GTK_ICON_THEME=Adwaita

exec satty \
  --filename "$SCREENSHOT_PATH" \
  --output-filename "$SCREENSHOT_PATH" \
  --early-exit all \
  --copy-command wl-copy \
  --actions-on-enter save-to-clipboard,save-to-file \
  --actions-on-escape save-to-clipboard,exit \
  --no-window-decoration \
  --floating-hack \
  --initial-tool crop
