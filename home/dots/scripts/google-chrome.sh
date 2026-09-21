#!/usr/bin/env bash
# Memory Saver + one renderer per site. Disk shader cache is unrelated.
set -euo pipefail

bin="${HOME:+/etc/profiles/per-user/${USER}/bin/google-chrome}"
if [ ! -x "$bin" ]; then
  bin="$(command -v google-chrome || true)"
fi
if [ -z "$bin" ] || [ ! -x "$bin" ]; then
  echo "google-chrome not found" >&2
  exit 127
fi

exec "$bin" \
  --force-dark-mode \
  --enable-features=WebUIDarkMode,MemorySaverMode \
  --disable-features=SpareRendererForSitePerProcess \
  --process-per-site \
  --renderer-process-limit=8 \
  "$@"
