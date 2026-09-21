#!/usr/bin/env bash
# Steam CEF is XWayland. Session GBM_BACKEND=nvidia-drm makes that surface
# black; GLX works if we drop GBM for this process tree. Software CEF at
# 2560x1080@200Hz is the hitchy unmanageable window.
set -euo pipefail
unset GBM_BACKEND
unset NVD_BACKEND
export GDK_BACKEND=x11
export GDK_SCALE=1
export GDK_DPI_SCALE=1
export STEAM_FORCE_DESKTOPUI_SCALING=1
export QT_AUTO_SCREEN_SCALE_FACTOR=0
export QT_QPA_PLATFORM=xcb
exec /run/current-system/sw/bin/steam \
  -forcedesktopscaling 1 \
  "$@"
