#!/usr/bin/env bash
set -euo pipefail

# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

url="${1:-}"
compose="${HOME}/.local/share/aurora/containers/telegram/compose.yml"
ipc="${HOME}/programs/telegram-1/ipc/telegram.url"
running="$(docker inspect -f '{{.State.Running}}' telegram-1 2>/dev/null || echo false)"

if [[ "$running" == "true" ]]; then
  [[ -z "$url" ]] && exit 0
  # shellcheck disable=SC2046
  docker exec -d -u telegram \
    $(space_display_env) \
    $(space_docker_env) \
    -e DBUS_SESSION_BUS_ADDRESS=unix:path=/tmp/xdg/bus \
    -e QT_QPA_PLATFORM=wayland \
    telegram-1 \
    /opt/Telegram/Telegram -workdir /home/telegram/.local/share/TelegramDesktop "$url"
  exit 0
fi

mkdir -p "${HOME}/programs/telegram-1/ipc"
if [[ -n "$url" ]]; then
  printf '%s\n' "$url" > "$ipc"
fi
docker compose -f "$compose" up -d --no-build telegram-1
