#!/usr/bin/env bash
# Thumbs are written by build-cursor-themes.py together with the XCursor files.
set -euo pipefail
exec python3 "${HOME}/Documents/projects/config/home/dots/scripts/build-cursor-themes.py" "$@"
