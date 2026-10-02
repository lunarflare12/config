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
# Compose interpolates ${QBITTORRENT_BIN} from the process env + .env file.
# Export so a stale .env still gets a real binary from gcroot fallback.
export QBITTORRENT_BIN=$bin

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
# Desktop click has no args — still need the GUI inside the box.
# shellcheck disable=SC2046
if ! docker exec qbittorrent pidof qbittorrent >/dev/null 2>&1; then
  docker exec -d -u app \
    $(space_display_env) \
    $(space_docker_env) \
    qbittorrent \
    "$bin"
fi
if [ "$#" -gt 0 ]; then
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    qbittorrent \
    "$bin" \
    "$@"
fi