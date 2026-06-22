#!/usr/bin/env bash
set -euo pipefail

dir="${HOME}/Pictures/wallpapers"
mapfile -t pics < <(
  find -L "$dir" -maxdepth 1 -type f \
    -regextype posix-extended \
    -iregex '.*\.(png|jpe?g|webp|gif|bmp)$' 2>/dev/null | sort
)

if ((${#pics[@]} == 0)); then
  notify-send -t 2000 "wallpaper" "Нет обоев в ${dir}" 2>/dev/null || true
  exit 1
fi

pick=$(printf '%s\n' "${pics[@]}" | fuzzel --dmenu --prompt "Обои")
[[ -n "$pick" ]] || exit 0

awww img "$pick" \
  --transition-type grow \
  --transition-duration 0.6 \
  --transition-fps 60 \
  --transition-pos center

mkdir -p "${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper"
printf '%s\n' "$pick" >"${XDG_STATE_HOME:-$HOME/.local/state}/wallpaper/current"
