#!/usr/bin/env bash
# Kept for direct invocation; PATH uses createSpace "idea-ultimate".
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

# DirectoryLock lives on the persistent home volume. Container PIDs restart
# from 1, so a leftover ".lock" PID looks like a live instance and IDEA exits 6.
if ! docker inspect -f '{{.State.Running}}' idea 2>/dev/null | grep -qx true; then
  rm -f "${HOME}/programs/idea/.config/JetBrains/"IntelliJIdea*/.lock
  rm -f "${HOME}/programs/idea/.cache/JetBrains/"IntelliJIdea*/.port
fi

exec docker compose -f "${HOME}/.local/share/aurora/containers/apps/compose.yml" up -d --no-build idea
