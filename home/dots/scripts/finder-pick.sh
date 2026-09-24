#!/usr/bin/env bash
# xdg-desktop-portal-termfilechooser → live Finder picker script.
# The nix wrapper bakes a store copy of finder-pick.py that still opened
# Thunar for directory picks. Keep its GTK/GI env, run the git-tree file.
set -euo pipefail

export GTK_THEME="${GTK_THEME:-WhiteSur-Dark}"
export GTK_APPLICATION_PREFER_DARK_THEME=1
export GTK_USE_PORTAL=0
export GDK_DEBUG=no-portals
export ADW_DEBUG_COLOR_SCHEME=prefer-dark

here=$(cd "$(dirname "$0")" && pwd)
py=$here/finder-pick.py

source_minus_exec() {
  local f=$1
  [[ -f $f ]] || return 1
  # shellcheck disable=SC1090
  source /dev/stdin <<<"$(sed '/^#!/d; /^exec /d' "$f")"
}

outer=${HOME}/.local/lib/aurora-finder-pick/bin/finder-pick
inner=${HOME}/.local/lib/aurora-finder-pick/bin/.finder-pick-wrapped
if [[ ! -f $outer ]]; then
  outer=$(command -v finder-pick 2>/dev/null || true)
  inner=
  if [[ -n $outer && -f $outer ]]; then
    inner=$(sed -n 's/.*exec -a "\$0" "\([^"]*\)".*/\1/p' "$outer" | head -n 1 || true)
  fi
fi

python=
if [[ -n ${outer:-} && -f $outer ]]; then
  set +u
  source_minus_exec "$outer" || true
  if [[ -n ${inner:-} && -f $inner ]]; then
    source_minus_exec "$inner" || true
    python=$(sed -n 's/^exec "\([^"]*\)".*/\1/p' "$inner" | head -n 1 || true)
  fi
  set -u
fi
[[ -n ${python:-} && -x $python ]] || python=$(command -v python3)

exec "$python" "$py" "$@"
