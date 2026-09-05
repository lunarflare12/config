#!/usr/bin/env bash
# Steam launch options:
#   /home/dd/.config/scripts/overwatch-stream.sh %command%
#
# Plays Overwatch at native 2560x1080 200Hz. OBS can upscale the
# vkcapture feed to 4K cheaper than rendering 4K inside the game.
set -euo pipefail

export OBS_VKCAPTURE="${OBS_VKCAPTURE:-1}"
export ENABLE_GAMESCOPE_WSI="${ENABLE_GAMESCOPE_WSI:-1}"
export PROTON_ENABLE_NVAPI="${PROTON_ENABLE_NVAPI:-1}"
export PROTON_HIDE_NVIDIA_GPU="${PROTON_HIDE_NVIDIA_GPU:-0}"
export __GL_SYNC_TO_VBLANK="${__GL_SYNC_TO_VBLANK:-0}"
export __GL_GSYNC_ALLOWED="${__GL_GSYNC_ALLOWED:-1}"

if command -v obs-gamecapture >/dev/null 2>&1; then
  set -- obs-gamecapture "$@"
fi

if command -v gamemoderun >/dev/null 2>&1; then
  set -- gamemoderun "$@"
fi

exec gamescope \
  -w 2560 \
  -h 1080 \
  -W 2560 \
  -H 1080 \
  -r 200 \
  -f \
  --force-grab-cursor \
  --adaptive-sync \
  --backend wayland \
  -- "$@"
