#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

space_load_apps_env
compose="${HOME}/containers/apps/compose.yml"
bin="${LIBREOFFICE_BIN:?LIBREOFFICE_BIN missing in containers/apps/.env}"

# Re-pin dark Colibre / Appearance before every launch so a previous session
# cannot leave light toolbar icons behind.
lo_home="${HOME}/programs/libreoffice"
ui_fix="${HOME}/.config/scripts/libreoffice-office-ui.py"
if [ ! -e "$lo_home/.config/libreoffice/4/.lock" ] && [ -f "$ui_fix" ]; then
  HOME="$lo_home" python3 "$ui_fix" >/dev/null 2>&1 || true
fi

docker compose -f "$compose" up -d --no-build libreoffice
if [ "$#" -gt 0 ]; then
  # shellcheck disable=SC2046
  docker exec -u app \
    $(space_display_env) \
    $(space_docker_env) \
    -e GDK_BACKEND=wayland \
    -e SAL_USE_VCLPLUGIN=gtk3 \
    -e GTK_THEME=WhiteSur-Dark \
    -e GTK_APPLICATION_PREFER_DARK_THEME=1 \
    -e ADW_DEBUG_COLOR_SCHEME=prefer-dark \
    libreoffice \
    "$bin" \
    "$@"
fi
