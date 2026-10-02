#!/usr/bin/env bash
# Kept for direct invocation; PATH uses createSpace "telegram-2".
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"
exec docker compose -f "${HOME}/containers/telegram/compose.yml" up -d --no-build telegram-2
