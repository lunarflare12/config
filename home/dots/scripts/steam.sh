#!/usr/bin/env bash
# Host launcher: Steam (+ games) run inside containers/steam.
# Desktop / steam:// links: ~/.config/scripts/steam.sh %U
set -euo pipefail

HOME="${HOME:-/home/dd}"
COMPOSE="${HOME}/.local/share/aurora/containers/steam/compose.yml"
# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/space-lib.sh"

if [ -x "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" ]; then
  "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" >/dev/null 2>&1 || true
fi
if [ -x "${BASH_SOURCE[0]%/*}/cap-fossilize.sh" ]; then
  "${BASH_SOURCE[0]%/*}/cap-fossilize.sh" >/dev/null 2>&1 || true
fi

# Host Steam must not hold the library while the container owns it.
if [ -z "${STEAM_CONTAINER:-}" ]; then
  if pgrep -f '/\.local/share/Steam/ubuntu12_32/steam' >/dev/null 2>&1; then
    # Only kill host steam, not the containerized one (same binary path though).
    if ! docker inspect -f '{{.State.Running}}' steam 2>/dev/null | grep -qx true; then
      pkill -f '/\.local/share/Steam/ubuntu12_32/steam' >/dev/null 2>&1 || true
      sleep 1
    fi
  fi
fi

uri="${1:-}"
case "$uri" in
  *105600*) exec "${BASH_SOURCE[0]%/*}/terraria.sh" ;;
  *761890*) exec "${BASH_SOURCE[0]%/*}/albion.sh" ;;
  *33100*) exec "${BASH_SOURCE[0]%/*}/alien-shooter.sh" ;;
esac

mkdir -p "${HOME}/programs/steam"
# One container. Old per-game boxes cannot share the library with this client.
docker rm -f overwatch terraria albion >/dev/null 2>&1 || true
docker compose -f "$COMPOSE" up -d --no-deps --no-build steam

# Wait until the container is up.
for _ in $(seq 1 30); do
  if docker inspect -f '{{.State.Running}}' steam 2>/dev/null | grep -qx true; then
    break
  fi
  sleep 0.2
done

if [ "$#" -eq 0 ]; then
  exit 0
fi

steam_bin="$(tr -d '\n' <"${HOME}/.local/share/aurora/steam-bin" 2>/dev/null || true)"
if [ -z "$steam_bin" ] || [ ! -x "$steam_bin" ]; then
  steam_bin="$(command -v steam-fhs 2>/dev/null || true)"
fi
if [ -z "$steam_bin" ] || [ ! -x "$steam_bin" ]; then
  echo "steam.sh: missing ~/.local/share/aurora/steam-bin (rebuild system with modules/steam.nix)" >&2
  exit 1
fi

# Forward steam:// / args into the running container Steam.
# shellcheck disable=SC2046
exec docker exec -u app \
  -e DISPLAY="${DISPLAY:-:0}" \
  -e STEAM_CONTAINER=1 \
  $(space_docker_env) \
  steam \
  "$steam_bin" -forcedesktopscaling 1 "$@"
