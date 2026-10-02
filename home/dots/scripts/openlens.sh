#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"
space_load_apps_env
compose="${HOME}/containers/apps/compose.yml"
bin="${OPENLENS_BIN:-${OPENLENS_APP:+$OPENLENS_APP/open-lens}}"
bin="${bin:?OPENLENS_APP missing in containers/apps/.env}"
docker compose -f "$compose" up -d --no-build openlens
if [ "$#" -gt 0 ]; then
  docker exec -u app -e XDG_RUNTIME_DIR=/tmp/xdg \
    -e WAYLAND_DISPLAY=wayland-1 \
    openlens \
    "$bin" \
    --ozone-platform=wayland \
    --no-sandbox \
    --disable-setuid-sandbox \
    "$@"
fi
