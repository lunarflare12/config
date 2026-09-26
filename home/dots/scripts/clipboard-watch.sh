#!/usr/bin/env bash
# wl-paste --watch target: normalize file copies, then store history.
set -euo pipefail
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER:-dd}/bin:${PATH:-}"
input=$(cat)
"${HOME}/.config/scripts/clipboard-as-file.sh" >/dev/null 2>&1 || true
printf '%s' "$input" | cliphist store
