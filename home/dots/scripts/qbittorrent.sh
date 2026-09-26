#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

space_load_apps_env
compose="${HOME}/.local/share/aurora/containers/apps/compose.yml"
if [[ -z "${QBITTORRENT_BIN:-}" && -e "${HOME}/.local/share/aurora/qbittorrent.gcroot" ]]; then
  QBITTORRENT_BIN="$(readlink -f "${HOME}/.local/share/aurora/qbittorrent.gcroot")/bin/qbittorrent"
fi
bin="${QBITTORRENT_BIN:?QBITTORRENT_BIN missing in containers/apps/.env}"

conf="${HOME}/programs/qbittorrent/.config/qBittorrent/qBittorrent.conf"
if [[ ! -f "$conf" ]]; then
  mkdir -p "${conf%/*}" "${HOME}/Downloads/torrents"
  cat >"$conf" <<'EOF'
[Preferences]
Connection\PortRangeMin=6881
Connection\UPnP=false
Downloads\SavePath=/home/app/Downloads
WebUI\Enabled=false
EOF
fi

docker compose -f "$compose" up -d --no-build qbittorrent
if [ "$#" -gt 0 ]; then
  # shellcheck disable=SC2046
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    qbittorrent \
    "$bin" \
    "$@"
fi
