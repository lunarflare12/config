#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

space_load_apps_env
compose="${HOME}/containers/apps/compose.yml"
bin="${LIBREOFFICE_BIN:?LIBREOFFICE_BIN missing in containers/apps/.env}"
docker compose -f "$compose" up -d --no-build libreoffice
if [ "$#" -gt 0 ]; then
  # shellcheck disable=SC2046
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    -e GDK_BACKEND=wayland \
    -e SAL_USE_VCLPLUGIN=gtk3 \
    libreoffice \
    "$bin" \
    "$@"
fi
