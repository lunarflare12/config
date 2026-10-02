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

# 0 = cache already compiled, Steam must not rebuild it.
# 1 = cache missing, Steam's shader processor runs before applaunch.
shader_processing() {
  mode=$1
  python3 - "$mode" <<'PY' || true
import re, sys
from pathlib import Path
mode = sys.argv[1]
p = Path("/home/dd/.local/share/Steam/config/config.vdf")
if not p.is_file():
    sys.exit(0)
t = p.read_text(errors="replace")
n = re.sub(
    r'("EnableShaderBackgroundProcessing"\s+)"[01]"',
    rf'\1"{mode}"',
    t,
    count=1,
)
if n != t:
    p.write_text(n)
PY
}

# Sum of real NVIDIA bins. Stubs of 32 bytes do not count as a cache.
# Overwatch's real cache is multi‑GB; 64MiB used to freeze mid‑compile and
# flip EnableShaderBackgroundProcessing off while fossilize was still writing.
cache_bytes() {
  # LC_ALL=C: a ru_RU awk prints "1,6e+10", and dash [ then aborts the launch.
  LC_ALL=C find /home/dd/.cache/nvidia/overwatch /home/dd/.cache/steam-shadercache/2357570/nvidiav1 \
    -type f -name '*.bin' -printf '%s\n' 2>/dev/null \
    | LC_ALL=C awk '{s+=$1} END{printf "%.0f\n", s+0}'
}

# Real OW NVIDIA cache floor. Below this: allow Steam rebuild, no .frozen.
OW_CACHE_READY_BYTES=2147483648

# pid=host: do not scan every /proc/*/exe (that's the whole machine).
# Match comm only — Overwatch.exe / Terraria.exe / Albion-Online.exe.
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

shutdown_steam() {
  "$steam_bin" -shutdown >/dev/null 2>&1 || true
  i=0
  while [ "$i" -lt 20 ] && steam_alive; do
    i=$((i + 1))
    sleep 0.25
  done
  if steam_alive; then
    pkill -f '/\.local/share/Steam/ubuntu12_32/steam' >/dev/null 2>&1 || true
    pkill -f '/\.local/share/Steam/steam.sh' >/dev/null 2>&1 || true
  fi
}

protect_caches() {
  if [ -x /home/dd/.config/scripts/protect-shader-caches.sh ]; then
    /home/dd/.config/scripts/protect-shader-caches.sh >/dev/null 2>&1 || true
  fi
}

# A real NVIDIA tree stays frozen and Steam must not rebuild it.
# Rebuilding is what truncated the Overwatch cache. Only an empty tree
# is allowed to compile.
for keep in \
  /home/dd/.cache/nvidia/terraria \
  /home/dd/.cache/nvidia/albion \
  /home/dd/.cache/nvidia/overwatch
do
  mkdir -p "$keep" 2>/dev/null || true
  printf 'protected\n' >"$keep/.aurora-no-delete"
done
ow_bytes=$(cache_bytes)
if [ "${ow_bytes:-0}" -ge "$OW_CACHE_READY_BYTES" ]; then
  printf 'frozen\n' >/home/dd/.cache/nvidia/overwatch/.frozen
  shader_processing 0
else
  # Empty/stub tree must not look frozen — Steam has to rebuild.
  rm -f /home/dd/.cache/nvidia/overwatch/.frozen
  shader_processing 1
fi
protect_caches

case "$appid" in
  105600) nv_name=terraria ;;
  761890) nv_name=albion ;;
  *) nv_name=overwatch ;;
esac
nv_path="/home/dd/.cache/nvidia/$nv_name"

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
# Overwatch: applaunch spawns the exe immediately. Wait until the
# pipeline depots are downloaded so Steam's percent window runs first.
if [ "$appid" = 2357570 ]; then
  bash -c '. /home/dd/.config/scripts/game-lib.sh && game_wait_ow_shaders' || exit 1
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
# Once a real cache exists, stop Steam from scheduling another rebuild.
if [ "${appid}" = 2357570 ]; then
  ow_bytes=$(cache_bytes)
  if [ "${ow_bytes:-0}" -ge "$OW_CACHE_READY_BYTES" ]; then
    printf 'frozen\n' >/home/dd/.cache/nvidia/overwatch/.frozen
    shader_processing 0
  fi
fi
exit 0
