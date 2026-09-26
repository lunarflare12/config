#!/usr/bin/env bash
# Classic / abandonware-owned games only. Not Steam, not GTA RP / FiveM.
# Those stay on their own launchers so installing them later does not
# pull this stack in, and this stack does not depend on them.
set -euo pipefail

HOME="${HOME:-/home/dd}"
mkdir -p "${HOME}/Games/old"

if command -v lutris >/dev/null 2>&1; then
  exec lutris "$@"
fi

exec nix run nixpkgs#lutris -- "$@"
