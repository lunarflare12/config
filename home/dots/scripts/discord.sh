#!/usr/bin/env bash
set -euo pipefail
# shellcheck disable=SC1091
source "${HOME}/.config/scripts/space-lib.sh"

# Official pkgs.discord crashes (SIGSEGV / early exit) on this NVIDIA+Hypr
# stack. Vesktop is the working client until/unless upstream discord is fixed.
bin=""
for cand in \
  /etc/profiles/per-user/dd/bin/vesktop \
  /run/current-system/sw/bin/vesktop \
  /nix/store/p219cslzixld55a7mp4qvwda8jjzsnsl-vesktop-1.6.7/bin/vesktop
do
  if [ -x "$cand" ]; then
    bin=$cand
    break
  fi
done
if [ -z "$bin" ]; then
  echo "discord.sh: vesktop not found (home-manager switch needed)" >&2
  exit 1
fi

export ELECTRON_OZONE_PLATFORM_HINT="${ELECTRON_OZONE_PLATFORM_HINT:-wayland}"
exec "$bin" --ozone-platform=wayland --force-dark-mode "$@"
