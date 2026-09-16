#!/usr/bin/env bash
# CEF without GPU compositing. Game Proton still uses the system steam binary.
exec /run/current-system/sw/bin/steam \
  -cef-disable-gpu \
  -cef-disable-gpu-compositing \
  "$@"
