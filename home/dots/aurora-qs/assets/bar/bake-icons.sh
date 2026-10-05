#!/usr/bin/env bash
# Rasterize bar SVGs at Theme.iconSize for 1:1 ThemeIcon display.
set -euo pipefail
dir=$(cd "$(dirname "$0")" && pwd)
size=${1:-26}
rsvg=$(command -v rsvg-convert || true)
if [[ -z $rsvg ]]; then
  rsvg=$(echo /nix/store/*/bin/rsvg-convert | awk '{print $1}')
fi
[[ -x $rsvg ]] || { echo "rsvg-convert not found" >&2; exit 1; }
for svg in "$dir"/*.svg; do
  base=$(basename "$svg" .svg)
  "$rsvg" -w "$size" -h "$size" "$svg" -o "$dir/${base}.png"
done
echo "baked $(ls "$dir"/*.png | wc -l) pngs at ${size}px"
