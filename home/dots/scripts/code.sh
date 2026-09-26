#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"
space_load_apps_env
compose="${HOME}/.local/share/aurora/containers/apps/compose.yml"
bin="${VSCODE_BIN:?VSCODE_BIN missing in containers/apps/.env}"
docker compose -f "$compose" up -d --no-build vscode
if [ "$#" -gt 0 ]; then
  docker exec -u app -e XDG_RUNTIME_DIR=/tmp/xdg \
    -e WAYLAND_DISPLAY=wayland-1 \
    vscode \
    "$bin" \
    --ozone-platform=wayland \
    --force-dark-mode \
    --no-sandbox \
    --disable-setuid-sandbox \
    --user-data-dir=/home/app/.config/Code \
    "$@"
fi
