#!/bin/sh
# Applaunch inside the one Steam container, then return when the game exits.
# The container's Steam client stays up. Do not start a second client.
set -eu

appid="${1:?appid}"
shift

steam_bin="$(tr -d '\n' </home/dd/.local/share/aurora/steam-bin 2>/dev/null || true)"
if [ -z "$steam_bin" ] || [ ! -x "$steam_bin" ]; then
  echo "game-session: missing ~/.local/share/aurora/steam-bin" >&2
  exit 1
fi

runtime="${XDG_RUNTIME_DIR:-/tmp/xdg}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$runtime/bus}"

# pid=host: do not scan every /proc/*/exe (that's the whole machine).
# Match comm only — Terraria.exe / Albion-Online.exe, etc.
game_alive() {
  for d in /proc/[0-9]*; do
    comm=$(cat "$d/comm" 2>/dev/null) || continue
    for pat in "$@"; do
      [ -n "$pat" ] || continue
      case "$comm" in
        "$pat")
          return 0
          ;;
      esac
    done
  done
  return 1
}

steam_alive() {
  pgrep -f '/\.local/share/Steam/ubuntu12_32/steam$' >/dev/null 2>&1 \
    || pgrep -f '/\.local/share/Steam/steam.sh' >/dev/null 2>&1
}

protect_caches() {
  if [ -x /home/dd/.config/scripts/protect-shader-caches.sh ]; then
    /home/dd/.config/scripts/protect-shader-caches.sh >/dev/null 2>&1 || true
  fi
}

for keep in \
  /home/dd/.cache/nvidia/terraria \
  /home/dd/.cache/nvidia/albion
do
  mkdir -p "$keep" 2>/dev/null || true
  printf 'protected\n' >"$keep/.aurora-no-delete"
done
protect_caches

case "$appid" in
  105600) nv_name=terraria ;;
  761890) nv_name=albion ;;
  *) nv_name="$appid" ;;
esac
nv_path="/home/dd/.cache/nvidia/$nv_name"
mkdir -p "$nv_path" 2>/dev/null || true

# The box entrypoint already runs Steam. Wait for it, then applaunch.
# No -silent: the shader progress window (percent + Skip) must be visible.
i=0
while [ "$i" -lt 60 ] && ! steam_alive; do
  i=$((i + 1))
  sleep 0.5
done
if ! steam_alive; then
  echo "game-session: steam is not running in this container" >&2
  exit 1
fi
"$steam_bin" -forcedesktopscaling 1 -applaunch "$appid" >/dev/null 2>&1 || true

appeared=0
i=0
# Shader precache (the percent window) runs before the exe exists.
# A few minutes is normal; bailing out here used to drop game-mode
# while Steam was still compiling.
while [ "$i" -lt 3600 ]; do
  if game_alive "$@"; then
    appeared=1
    break
  fi
  if ! steam_alive; then
    exit 1
  fi
  i=$((i + 1))
  sleep 1
done

if [ "$appeared" -eq 0 ]; then
  exit 1
fi

# Proton restarts the exe once while the client connects. A short gap
# is enough; 15s is why quit sat there after the window was already gone.
miss=0
while [ "$miss" -lt 3 ]; do
  if game_alive "$@"; then
    miss=0
  else
    miss=$((miss + 1))
  fi
  sleep 1
done

protect_caches
exit 0
