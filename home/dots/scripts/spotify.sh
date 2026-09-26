#!/usr/bin/env bash
# Kept for direct invocation; PATH uses createSpace "spotify".
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"
mkdir -p "${HOME}/.config/spicetify" "${HOME}/.cache/aurora/spotify-xpui/extensions"

if [[ -f "${HOME}/.cache/aurora/spotify-compose.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${HOME}/.cache/aurora/spotify-compose.env"
  set +a
fi

# Theme + xpui overlay must not block the window coming up.
(
  if command -v python3 >/dev/null 2>&1 && [[ -f "${HOME}/.config/scripts/spotify-theme" ]]; then
    python3 "${HOME}/.config/scripts/spotify-theme" >/dev/null 2>&1 || true
  fi
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
) >/dev/null 2>&1 &

# compose up parses the whole stack. An existing container is just docker start.
state="$(docker inspect -f '{{.State.Status}}' spotify 2>/dev/null || true)"
if [[ "$state" == "running" ]]; then
  exit 0
fi
if [[ -n "$state" ]]; then
  exec docker start spotify
fi
exec docker compose -f "${HOME}/.local/share/aurora/containers/apps/compose.yml" up -d --no-build spotify
