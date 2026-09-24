#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

space_load_apps_env
compose="${HOME}/containers/apps/compose.yml"
docker compose -f "$compose" up -d --no-build zen
if [ "$#" -gt 0 ]; then
  # shellcheck disable=SC2046
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    -e MOZ_ENABLE_WAYLAND=1 \
    zen \
    "${ZEN_BIN:?ZEN_BIN missing in containers/apps/.env}" \
    --profile /home/app/.zen --no-remote \
    "$@"
fi
