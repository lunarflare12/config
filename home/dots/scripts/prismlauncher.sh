#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

space_load_apps_env
compose="${HOME}/.local/share/aurora/containers/apps/compose.yml"
if [[ -z "${PRISM_BIN:-}" && -e "${HOME}/.local/share/aurora/prismlauncher.gcroot" ]]; then
  PRISM_BIN="$(readlink -f "${HOME}/.local/share/aurora/prismlauncher.gcroot")/bin/prismlauncher"
fi
bin="${PRISM_BIN:?PRISM_BIN missing in containers/apps/.env}"

docker compose -f "$compose" up -d --no-build prismlauncher
if [ "$#" -gt 0 ]; then
  # shellcheck disable=SC2046
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    prismlauncher \
    "$bin" \
    "$@"
fi
