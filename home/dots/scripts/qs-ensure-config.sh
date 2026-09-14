#!/usr/bin/env bash
# Point ~/.config/quickshell at the git tree. Never fail: systemd start-limit
# used to kill the bar when a copy onto the nix-store path got EROFS.
set +e

SRC="${HOME}/config/home/dots/aurora-qs"
DST="${HOME}/.config/quickshell"

src_real=$(readlink -f "$SRC" 2>/dev/null || true)
dst_real=$(readlink -f "$DST" 2>/dev/null || true)

if [ -d "$SRC" ] && [ -n "$src_real" ] && [ "$dst_real" != "$src_real" ]; then
  rm -rf "$DST" 2>/dev/null
  ln -sfn "$SRC" "$DST" 2>/dev/null
fi

exit 0
