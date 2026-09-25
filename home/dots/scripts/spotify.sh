#!/usr/bin/env bash
# Kept for direct invocation; PATH uses createSpace "spotify".
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"
mkdir -p "${HOME}/.config/spicetify" "${HOME}/.cache/aurora/spotify-xpui/extensions"
# Compose .env is HM-managed. Sidecar keeps spice paths live until the next switch.
if [[ -f "${HOME}/.cache/aurora/spotify-compose.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${HOME}/.cache/aurora/spotify-compose.env"
  set +a
fi
if command -v python3 >/dev/null 2>&1 && [[ -f "${HOME}/.config/scripts/spotify-theme" ]]; then
  python3 "${HOME}/.config/scripts/spotify-theme" >/dev/null 2>&1 || true
fi
# Refresh xpui overlay so Aurora colors sit on the current Dribbblish build.
if [[ -n "${SPOTIFY_XPUI:-}" && -d "${SPOTIFY_XPUI}/extensions" ]]; then
  over="${HOME}/.cache/aurora/spotify-xpui"
  stamp="${over}/.extensions-src"
  if [[ ! -d "${over}/extensions" || ! -f "$stamp" || "$(cat "$stamp")" != "$SPOTIFY_XPUI" ]]; then
    rm -rf "${over}/extensions"
    mkdir -p "${over}/extensions"
    cp -a "${SPOTIFY_XPUI}/extensions/." "${over}/extensions/"
    chmod -R u+w "${over}/extensions"
    printf '%s\n' "$SPOTIFY_XPUI" >"$stamp"
  fi
  [[ -f "${over}/aurora.js" ]] && cp -f "${over}/aurora.js" "${over}/extensions/aurora.js"
fi
exec docker compose -f "${HOME}/containers/apps/compose.yml" up -d --no-build spotify
