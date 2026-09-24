#!/usr/bin/env bash
# Kept for direct invocation; PATH uses createSpace "idea-ultimate".
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"
exec docker compose -f "${HOME}/containers/apps/compose.yml" up -d --no-build idea
