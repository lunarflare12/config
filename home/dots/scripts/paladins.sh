#!/usr/bin/env bash
# Steam launch options (kept in localconfig by steam-lock-shaders.sh):
#   /home/dd/.config/scripts/paladins.sh %command%
set -euo pipefail

HOME="${HOME:-/home/dd}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

game_block_fossilize
game_low_latency

export PROTON_ENABLE_NVAPI="${PROTON_ENABLE_NVAPI:-1}"
export PROTON_HIDE_NVIDIA_GPU="${PROTON_HIDE_NVIDIA_GPU:-0}"
export PROTON_ENABLE_NGX_UPDATER=0
export __GL_SYNC_TO_VBLANK=0
export __GL_GSYNC_ALLOWED="${__GL_GSYNC_ALLOWED:-1}"
export DXVK_HDR=0
export DXVK_STATE_CACHE=1
export DXVK_STATE_CACHE_PATH="${DXVK_STATE_CACHE_PATH:-$XDG_CACHE_HOME/dxvk}"
# Proton + gamescope WSI eats relative mouse. Nested SDL on Xwayland does not.
export ENABLE_GAMESCOPE_WSI=0
export SDL_VIDEODRIVER=x11
mkdir -p "$DXVK_STATE_CACHE_PATH" "$XDG_CONFIG_HOME/dxvk"
export DXVK_CONFIG_FILE="$XDG_CONFIG_HOME/dxvk/paladins.conf"
export PROTON_DXVK_CONFIG_FILE="$DXVK_CONFIG_FILE"
cat >"$DXVK_CONFIG_FILE" <<EOF
dxgi.syncInterval = 0
dxgi.maxFrameLatency = 1
d3d9.maxFrameLatency = 1
dxvk.maxDeviceMemory = 8192
dxvk.maxSharedMemory = 3072
EOF

read -r width height refresh output <<<"$(game_monitor)"
refresh=${refresh:-200}
output=${output:-DP-1}

gs=$(game_gamescope || true)
ultrawide=0
[ $((width * 10 / height)) -ge 20 ] && ultrawide=1

inner_w=$width
inner_h=$height
if [ "$ultrawide" = 1 ] && [ -n "$gs" ]; then
  inner_h=$height
  inner_w=$((height * 16 / 9))
fi

ini="/steam/steamapps/compatdata/444090/pfx/drive_c/users/steamuser/Documents/My Games/Paladins/ChaosGame/Config/ChaosSystemSettings.ini"
engine="/steam/steamapps/compatdata/444090/pfx/drive_c/users/steamuser/Documents/My Games/Paladins/ChaosGame/Config/ChaosEngine.ini"
gameini="/steam/steamapps/compatdata/444090/pfx/drive_c/users/steamuser/Documents/My Games/Paladins/ChaosGame/Config/ChaosGame.ini"

game_ini_set "$ini" "[SystemSettings]" "Fullscreen" "False"
game_ini_set "$ini" "[SystemSettings]" "FullscreenWindowed" "True"
game_ini_set "$ini" "[SystemSettings]" "Borderless" "True"
game_ini_set "$ini" "[SystemSettings]" "ResX" "$inner_w"
game_ini_set "$ini" "[SystemSettings]" "ResY" "$inner_h"
game_ini_set "$ini" "[SystemSettings]" "UseVsync" "False"
game_ini_set "$ini" "[SystemSettings]" "OneFrameThreadLag" "False"
game_ini_set "$ini" "[SystemSettings]" "VsyncPresentInterval" "0"
game_ini_set "$ini" "[SystemSettings]" "bUseTripleBuffering" "False"

if [ -f "$engine" ]; then
  game_ini_set "$engine" "[Engine.Engine]" "bPauseOnLossOfFocus" "False"
  game_ini_set "$engine" "[Engine.Engine]" "bSmoothFrameRate" "False"
  game_ini_set "$engine" "[Engine.GameEngine]" "bPauseOnLossOfFocus" "False"
  game_ini_set "$engine" "[Engine.GameEngine]" "bSmoothFrameRate" "False"
fi

if [ -f "$gameini" ]; then
  game_ini_set "$gameini" "[TgGame.TgClientSettings]" "DesiredAspectRatio" "SETTINGAR_16x9"
fi

game_wine_warp "/steam/steamapps/compatdata/444090/pfx/user.reg" disable
game_x_primary "$width" "$height"
game_strip_overlay

{
  echo "$(date -Iseconds) monitor ${width}x${height}@${refresh} ${output} ultrawide=${ultrawide} gamescope=${gs:-none} inner=${inner_w}x${inner_h}"
} >>"${XDG_CACHE_HOME}/paladins-launch.log" 2>/dev/null || true

if [ "$ultrawide" = 1 ] && [ -n "$gs" ]; then
  gs_rt=()
  [ "$gs" = /run/wrappers/bin/gamescope ] && gs_rt=(--rt)
  if command -v gamemoderun >/dev/null 2>&1; then
    set -- gamemoderun "$@"
  fi
  # Nested SDL on Xwayland. Paladins keeps a Coherent UI cursor even in a
  # match, so gamescope will not switch to relative mouse on its own.
  # --force-grab-cursor is required for look; do not pair it with Wine
  # MouseWarpOverride=force or Hyprland confine_pointer (pins to the corner).
  exec "$gs" \
    --backend sdl \
    -w "$inner_w" \
    -h "$inner_h" \
    -W "$width" \
    -H "$height" \
    -r "$refresh" \
    -f \
    -S stretch \
    -F linear \
    --cursor-scale-height "$inner_h" \
    --force-grab-cursor \
    --force-windows-fullscreen \
    --immediate-flips \
    "${gs_rt[@]}" \
    -- "$@"
fi

if command -v gamemoderun >/dev/null 2>&1; then
  exec gamemoderun "$@"
fi
exec "$@"
