#!/usr/bin/env bash
set -euo pipefail
# Official pkgs.discord SIGSEGV / exits on this NVIDIA+Hypr stack.
# Vesktop is the working client (window class: vesktop).

bin=""
if command -v vesktop >/dev/null 2>&1; then
  bin="$(command -v vesktop)"
else
  for cand in \
    /etc/profiles/per-user/dd/bin/vesktop \
    /run/current-system/sw/bin/vesktop \
    "$HOME/.nix-profile/bin/vesktop"
  do
    if [ -x "$cand" ]; then
      bin=$cand
      break
    fi
  done
fi

# Profile may still point at pkgs.discord after a vesktop switch that
# hasn't been activated — grab the newest store build as last resort.
if [ -z "$bin" ]; then
  bin=$(ls -dt /nix/store/*-vesktop-*/bin/vesktop 2>/dev/null | head -1 || true)
fi

if [ -z "${bin:-}" ] || [ ! -x "$bin" ]; then
  echo "discord.sh: vesktop not found (home-manager switch needed)" >&2
  exit 1
fi

export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-wayland}"
exec "$bin" \
  --ozone-platform=wayland \
  --force-dark-mode \
  --js-flags="--max-old-space-size=512" \
  "$@"
