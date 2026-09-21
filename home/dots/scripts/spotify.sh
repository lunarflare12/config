#!/usr/bin/env bash
# Spotify + Spicetify inside wayland-box (namespaces + isolated HOME).
set -euo pipefail

BOX="${HOME}/.config/scripts/wayland-box.sh"
BOX_HOME="${HOME}/.local/share/wayland-box/spotify"
SPOTIFY_CONFIG="${HOME}/.config/spotify"
SPOTIFY_CACHE="${HOME}/.cache/spotify"
SPICETIFY_CONFIG="${HOME}/.config/spicetify"

MODE=app
if [[ "${1:-}" == "--cli" ]]; then
  MODE=cli
  shift
fi

resolve_spotify() {
  if [[ -n "${SPOTIFY_BIN:-}" && -x "${SPOTIFY_BIN}" ]]; then
    printf '%s\n' "$SPOTIFY_BIN"
    return 0
  fi

  local p
  for p in /nix/store/*-spicetify-Dribbblish/bin/spotify /nix/store/*-spicetify-*/bin/spotify /nix/store/*-spotify-*/bin/spotify; do
    [[ -x "$p" ]] || continue
    [[ "$p" == *-spicetify-Default/* ]] && continue
    printf '%s\n' "$p"
    return 0
  done
  echo "spotify: spiced Spotify not found" >&2
  exit 1
}

resolve_spicetify() {
  if [[ -n "${SPICETIFY_BIN:-}" && -x "${SPICETIFY_BIN}" ]]; then
    printf '%s\n' "$SPICETIFY_BIN"
    return 0
  fi

  local p
  for p in /nix/store/*-spicetify-cli-*/bin/spicetify; do
    [[ -x "$p" ]] || continue
    printf '%s\n' "$p"
    return 0
  done
  echo "spotify: spicetify CLI not found" >&2
  exit 1
}

mkdir -p "$SPOTIFY_CONFIG" "$SPOTIFY_CACHE" "$SPICETIFY_CONFIG" "$BOX_HOME"

# Chromium exits immediately if SingletonLock points at a dead pid.
lock="$SPOTIFY_CACHE/SingletonLock"
if [[ -e "$lock" ]]; then
  target=$(readlink "$lock" 2>/dev/null || true)
  pid="${target##*-}"
  if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
    rm -f "$lock" "$SPOTIFY_CACHE/SingletonCookie" "$SPOTIFY_CACHE/SingletonSocket"
  fi
fi

BINDS=(
  --bind "$SPOTIFY_CONFIG"
  --bind "$SPOTIFY_CACHE"
  --bind "$SPICETIFY_CONFIG"
)

THEME="$HOME/.config/scripts/spotify-theme"
if [[ -f "$THEME" ]]; then
  python3 "$THEME" >/dev/null 2>&1 || true
fi
OVER="$HOME/.cache/aurora/spotify-xpui"
BIN=""
if [[ "$MODE" == cli ]]; then
  BIN="$(resolve_spicetify)"
  BIN="$(readlink -f "$BIN")"
  ARGS=("$@")
else
  BIN="$(resolve_spotify)"
  ARGS=(--no-sandbox "$@")
  real="$(readlink -f "$BIN")"
  xpui="$(readlink -f "$(dirname "$real")/Apps/xpui")"
  if [[ ! -d "$xpui" ]]; then
    xpui="$(readlink -f "$(dirname "$real")/../share/spotify/Apps/xpui")"
  fi
  if [[ -d "$xpui" && -d "$OVER" ]]; then
    [[ -f "$OVER/colors.css" && -f "$xpui/colors.css" ]] && BINDS+=(--map "$OVER/colors.css" "$xpui/colors.css")
    [[ -f "$OVER/index.html" && -f "$xpui/index.html" ]] && BINDS+=(--map "$OVER/index.html" "$xpui/index.html")
    # aurora.js is new — bwrap cannot create it inside the read-only store, so
    # bind a writable copy of the whole extensions dir instead.
    if [[ -f "$OVER/aurora.js" && -d "$xpui/extensions" ]]; then
      ext_work="$OVER/extensions"
      stamp="$OVER/.extensions-src"
      if [[ ! -d "$ext_work" || ! -f "$stamp" || "$(cat "$stamp")" != "$xpui" ]]; then
        chmod -R u+w "$ext_work" 2>/dev/null || true
        rm -rf "$ext_work"
        mkdir -p "$ext_work"
        cp -a "$xpui/extensions/." "$ext_work/"
        chmod -R u+w "$ext_work"
        printf '%s\n' "$xpui" >"$stamp"
      fi
      cp -f "$OVER/aurora.js" "$ext_work/aurora.js"
      BINDS+=(--map "$ext_work" "$xpui/extensions")
    fi
  fi
fi
if [[ ! -x "$BIN" ]]; then
  echo "spotify: resolved binary is not executable: $BIN" >&2
  exit 1
fi

exec "$BOX" --name spotify "${BINDS[@]}" -- "$BIN" "${ARGS[@]}"
