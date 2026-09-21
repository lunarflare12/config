#!/usr/bin/env bash
set -euo pipefail

thumb_dir="${XDG_CACHE_HOME:-$HOME/.cache}/aurora/wallpaper-thumbs"
mkdir -p "$thumb_dir"

pick_magick() {
  command -v magick 2>/dev/null && return 0
  local found
  found=$(ls -1 /nix/store/*-imagemagick-*/bin/magick 2>/dev/null | tail -n 1 || true)
  if [ -n "$found" ] && [ -x "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  return 1
}

pick_ffmpeg() {
  command -v ffmpeg 2>/dev/null && return 0
  local found
  found=$(ls -1 /nix/store/*-ffmpeg-*/bin/ffmpeg 2>/dev/null | tail -n 1 || true)
  if [ -n "$found" ] && [ -x "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi
  return 1
}

magick_bin=$(pick_magick || true)
ffmpeg_bin=$(pick_ffmpeg || true)

if [ -z "$magick_bin" ] && [ -z "$ffmpeg_bin" ]; then
  printf 'cache-wallpaper-thumbs: no magick/ffmpeg\n' >&2
  exit 0
fi

resize_one() {
  local src="$1"
  local dest="$2"
  if [ -n "$magick_bin" ]; then
    "$magick_bin" "$src" -resize "384x216^" -gravity center -extent 384x216 -quality 70 -strip "$dest"
    return
  fi
  "$ffmpeg_bin" -y -loglevel error -i "$src" -vf "scale=384:216:force_original_aspect_ratio=increase,crop=384:216" -q:v 6 "$dest"
}

scan_dir() {
  local dir="$1"
  [ -d "$dir" ] || return 0
  find -L "$dir" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.gif" \) ! -name ".*" -print0 |
    while IFS= read -r -d "" src; do
      local name stem dest
      name=$(basename "$src")
      stem=${name%.*}
      dest="$thumb_dir/${stem}.jpg"
      if [ -f "$dest" ] && [ ! "$src" -nt "$dest" ]; then
        continue
      fi
      resize_one "$src" "$dest" || true
    done
}

for dir in "$@"; do
  scan_dir "$dir"
done

if [ "$#" -eq 0 ]; then
  scan_dir "$HOME/Wallpapers"
fi
