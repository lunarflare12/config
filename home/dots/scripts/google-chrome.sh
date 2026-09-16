#!/usr/bin/env bash
# Memory Saver + one renderer per site. Disk shader cache is unrelated.
exec /run/current-system/sw/bin/google-chrome-stable \
  --force-dark-mode \
  --enable-features=WebUIDarkMode,MemorySaverMode \
  --disable-features=SpareRendererForSitePerProcess \
  --process-per-site \
  --renderer-process-limit=8 \
  "$@"
