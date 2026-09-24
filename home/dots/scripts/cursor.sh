#!/usr/bin/env bash
# Launcher must exec the binary. Cursor's tray Activate does not raise
# the window on this session, and activate-existing then swallows the click.
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

unset NIXOS_OZONE_WL
unset ELECTRON_OZONE_PLATFORM_HINT
export GTK_USE_PORTAL=1

bin="/run/current-system/sw/bin/cursor"
if [ ! -x "$bin" ]; then
  bin="$(command -v cursor || true)"
fi
if [ -z "$bin" ]; then
  printf 'cursor.sh: cursor binary not found\n' >&2
  exit 1
fi
exec "$bin" --ozone-platform=wayland --force-dark-mode "$@"
