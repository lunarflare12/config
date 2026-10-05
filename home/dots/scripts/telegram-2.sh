#!/usr/bin/env bash
# Kept for direct invocation; PATH uses createSpace "telegram-2".
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"
if ! docker image inspect telegram-desktop:7.2.9 >/dev/null 2>&1; then
  exec "${HOME}/.config/scripts/telegram-1.sh"
fi
exec docker compose -f "${HOME}/containers/telegram/compose.yml" up -d --no-build telegram-2
