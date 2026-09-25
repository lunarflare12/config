#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

space_load_apps_env
compose="${HOME}/containers/apps/compose.yml"
chrome="${CHROME_BIN:?CHROME_BIN missing in containers/apps/.env}"
docker compose -f "$compose" up -d --no-build chrome-sciencesoft
if [ "$#" -gt 0 ]; then
  # shellcheck disable=SC2046
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    chrome-sciencesoft \
    "$chrome" \
    --user-data-dir=/home/app/.config/google-chrome \
    --profile-directory=Default \
    --class=chrome-sciencesoft \
    --proxy-server=socks5://127.0.0.1:1080 \
    --host-resolver-rules="MAP * ~NOTFOUND , EXCLUDE 127.0.0.1" \
    --ozone-platform=wayland \
    --force-dark-mode \
    --ignore-gpu-blocklist \
    --enable-gpu-rasterization \
    --enable-zero-copy \
    --no-sandbox \
    --disable-features=MemorySaverMode \
    "$@"
fi
