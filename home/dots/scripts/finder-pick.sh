#!/usr/bin/env bash
# xdg-desktop-portal-termfilechooser wrapper → Finder / WhiteSur picker.
set -euo pipefail

export GTK_THEME="${GTK_THEME:-WhiteSur-Dark}"
export GTK_APPLICATION_PREFER_DARK_THEME=1
export GTK_USE_PORTAL=0
export GDK_DEBUG=no-portals
export ADW_DEBUG_COLOR_SCHEME=prefer-dark

here=$(cd "$(dirname "$0")" && pwd)
py=$here/finder-pick.py

wrapped=
for c in \
  "$HOME/.local/lib/aurora-finder-pick/bin/finder-pick" \
  "$(command -v finder-pick 2>/dev/null || true)"; do
  if [[ -n $c && -x $c && $c != "$0" && $(basename "$c") != finder-pick.sh ]]; then
    wrapped=$c
    break
  fi
done

if [[ -n $wrapped ]]; then
  exec "$wrapped" "$@"
fi

exec python3 "$py" "$@"
