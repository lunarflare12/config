#!/usr/bin/env bash
# Host launcher: Terraria runs in containers/steam service `terraria`.
set -euo pipefail

HOME="${HOME:-/home/dd}"
COMPOSE="${HOME}/containers/steam/compose.yml"
# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

if [ -n "${STEAM_CONTAINER:-}" ] || [ -f /.dockerenv ]; then
  echo "terraria.sh: host launcher, not a launch-option wrapper" >&2
  exit 1
fi

if [ -x "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" ]; then
  "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" >/dev/null 2>&1 || true
fi

game_ensure_xwayland
game_stop_other_boxes terraria
mkdir -p "${HOME}/programs/steam"
game_ensure_steam
exec docker exec steam /usr/local/bin/game-session.sh 105600 Terraria.bin Terraria.exe
