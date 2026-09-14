#!/usr/bin/env bash
# Steam launch options:
#   /home/dd/.config/scripts/albion.sh %command%
# Native Unity. Exclusive fullscreen + Hyprland client-FS leaves the
# email-code field without text input (keys go nowhere).
set -euo pipefail

# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

game_strip_overlay
game_low_latency

export SDL_VIDEODRIVER=x11
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
  exec gamemoderun "${args[@]}" -screen-fullscreen 0
fi
exec "${args[@]}" -screen-fullscreen 0
