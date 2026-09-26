#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

space_load_apps_env
compose="${HOME}/.local/share/aurora/containers/apps/compose.yml"
bin="${OBSIDIAN_BIN:?OBSIDIAN_BIN missing in containers/apps/.env}"
docker compose -f "$compose" up -d --no-build obsidian
if [ "$#" -gt 0 ]; then
  # shellcheck disable=SC2046
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    obsidian \
    "$bin" \
    --ozone-platform=wayland \
    --force-dark-mode \
    --no-sandbox \
    --disable-setuid-sandbox \
    "$@"
fi
