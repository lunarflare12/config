#!/usr/bin/env bash
# Steam launch options:
#   /home/dd/.config/scripts/albion.sh %command%
# Native Unity. Exclusive fullscreen + Hyprland client-FS leaves the
# email-code field without text input (keys go nowhere).
set -euo pipefail

# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

in_box=0
if [ -n "${STEAM_CONTAINER:-}" ] || [ -f /.dockerenv ]; then
  in_box=1
fi

# Host: own container. Inside the box this file is the Steam launch wrapper.
if [ "$in_box" -eq 0 ]; then
  HOME="${HOME:-/home/dd}"
  COMPOSE="${HOME}/.local/share/aurora/containers/steam/compose.yml"
  if [ -x "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" ]; then
    "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" >/dev/null 2>&1 || true
  fi
  game_ensure_xwayland
  game_stop_other_boxes albion
  mkdir -p "${HOME}/programs/steam"
  game_ensure_steam
  exec docker exec steam /usr/local/bin/game-session.sh 761890 Albion-Online AlbionOnline
fi

game_strip_overlay
game_low_latency
albion_nv="${XDG_CACHE_HOME:-$HOME/.cache}/nvidia/albion"
mkdir -p "$albion_nv"
printf 'frozen\n' >"$albion_nv/.frozen"
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export __GL_SHADER_DISK_CACHE_SIZE="${__GL_SHADER_DISK_CACHE_SIZE:-34359738368}"
export __GL_SHADER_DISK_CACHE_PATH="$albion_nv"
export __GL_SHADER_DISK_CACHE_APP_NAME=steamapp_shader_cache
export __GL_SHADER_DISK_CACHE_READ_ONLY_APP_NAME="steam_shader_cache;steamapp_merged_shader_cache"
game_xwayland_ultrawide

export SDL_VIDEODRIVER=x11
export SDL_VIDEO_FULLSCREEN_DISPLAY="${SDL_VIDEO_FULLSCREEN_DISPLAY:-0}"

prefs="${HOME}/.config/unity3d/Sandbox Interactive GmbH/Albion Online Client/prefs"
if [ -f "$prefs" ]; then
  sed -i \
    -e 's/\(Screenmanager Resolution Width" type="int">\)[0-9]*/\12560/' \
    -e 's/\(Screenmanager Resolution Height" type="int">\)[0-9]*/\11080/' \
    -e 's/\(UnitySelectMonitor" type="int">\)[0-9]*/\11/' \
    "$prefs" || true
fi
unset GTK_IM_MODULE QT_IM_MODULE SDL_IM_MODULE XMODIFIERS || true

# Codes are latin. Hyprland us,ru + F24 leaves Moonlander on Russian, and
# Unity's field drops Cyrillic so letters never appear. Pin US around
# launcher start AND when the Unity client actually maps (a few seconds later).
albion_pin_us() {
  game_host hyprctl switchxkblayout zsa-technology-labs-moonlander-mark-i 0 >/dev/null 2>&1 || true
}
albion_pin_us
(
  for _ in $(seq 1 40); do
    albion_pin_us
    sleep 1
  done
) &
disown || true

args=()
skip_next=0
for a in "$@"; do
  if [ "$skip_next" = 1 ]; then
    skip_next=0
    continue
  fi
  case "$a" in
    -screen-fullscreen)
      skip_next=1
      ;;
    "-screen-fullscreen 1" | "-screen-fullscreen 0")
      ;;
    +fullscreen)
      ;;
    *)
      args+=("$a")
      ;;
  esac
done

if command -v gamemoderun >/dev/null 2>&1; then
  exec gamemoderun "${args[@]}" -screen-fullscreen 0 -screen-width 2560 -screen-height 1080 -monitor 1
fi
exec "${args[@]}" -screen-fullscreen 0 -screen-width 2560 -screen-height 1080 -monitor 1
