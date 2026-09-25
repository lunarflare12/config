#!/usr/bin/env bash
set -euo pipefail
# Official pkgs.discord crashes (SIGSEGV / early exit) on this NVIDIA+Hypr
# stack. Vesktop is the working client until/unless upstream discord is fixed.

bin=""
if command -v vesktop >/dev/null 2>&1; then
  bin="$(command -v vesktop)"
else
  for cand in \
    /etc/profiles/per-user/dd/bin/vesktop \
    /run/current-system/sw/bin/vesktop
  do
    if [ -x "$cand" ]; then
      bin=$cand
      break
    fi
  done
fi
if [ -z "$bin" ]; then
  echo "discord.sh: vesktop not found (home-manager switch needed)" >&2
  exit 1
fi

export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-wayland}"
exec "$bin" --ozone-platform=wayland --force-dark-mode "$@"
