#!/usr/bin/env bash
# Convert vsthemes cursor packs into XCursor themes.
set -euo pipefail
script="$(cd "$(dirname "$0")" && pwd)/install-cursors.py"
export MAGICK="${MAGICK:-$(command -v magick || true)}"
if [[ -z "${MAGICK}" ]]; then
  MAGICK="$(ls -1 /nix/store/*-imagemagick-*/bin/magick 2>/dev/null | tail -n1 || true)"
  export MAGICK
fi
if python3 -c 'import numpy, wand' >/dev/null 2>&1; then
  exec python3 "$script" "$@"
fi
exec nix-shell -p python3 python3Packages.numpy python3Packages.wand imagemagick unar --run "export MAGICK=\$(command -v magick); python3 '$script' $*"
