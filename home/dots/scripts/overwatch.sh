#!/usr/bin/env bash
# Steam launch options:
#   /home/dd/.config/scripts/overwatch.sh %command%
set -euo pipefail

HOME="${HOME:-/home/dd}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

game_block_fossilize
game_low_latency
# Do not wait for gamemoded: hide the bar and drop reserved zone before Proton maps.
if [ -x "${BASH_SOURCE[0]%/*}/gamemode-start.sh" ]; then
  "${BASH_SOURCE[0]%/*}/gamemode-start.sh" >/dev/null 2>&1 || true
fi
if [ -x "${BASH_SOURCE[0]%/*}/ow-stretch-plugin.sh" ]; then
  "${BASH_SOURCE[0]%/*}/ow-stretch-plugin.sh" >/dev/null 2>&1 || true
fi

export PROTON_ENABLE_NVAPI="${PROTON_ENABLE_NVAPI:-1}"
export PROTON_HIDE_NVIDIA_GPU="${PROTON_HIDE_NVIDIA_GPU:-0}"
export PROTON_ENABLE_NGX_UPDATER=0
# Reflex / ForceSync / MaxFramesAllowed=1 stall the 8-thread 7700.
export DXVK_NVAPI_VKREFLEX=0
# Fossilize layer inside the match hitchs the 8-thread 7700.
export DISABLE_VK_LAYER_VALVE_steam_fossilize_1=1
# No /dev/ntsync on this kernel; Wine probing it adds extra waits.
export PROTON_NO_NTSYNC=1
export DXVK_FILTER_DEVICE_NAME="${DXVK_FILTER_DEVICE_NAME:-NVIDIA}"
export __GL_SYNC_TO_VBLANK=0
export __GL_SYNC_DISPLAY_DEVICE="${__GL_SYNC_DISPLAY_DEVICE:-DP-1}"
export __GL_SHARPEN_ENABLE=0
export DXVK_HDR=0
export DXVK_STATE_CACHE=1
# Disk cache cap. 32GiB made the NVIDIA driver keep a huge working set in RAM.
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export __GL_SHADER_DISK_CACHE_SIZE="${__GL_SHADER_DISK_CACHE_SIZE:-8589934592}"
# One limiter only: Overwatch FrameRateCap=205. DXVK_FRAME_RATE on top of that
# beats against the 200Hz compositor and microstutters.
unset DXVK_FRAME_RATE || true
# Xiaomi DP-1 is not VRR/GSYNC capable.
export __GL_GSYNC_ALLOWED=0
export __GL_VRR_ALLOWED=0
export WINEFSYNC=1
export WINEESYNC=1
export PROTON_NO_ESYNC=0
export PROTON_NO_FSYNC=0
# Proton's Xalia overlay (xalia.exe) sits on the input path.
export PROTON_NO_XALIA=1
export PROTON_USE_XALIA=0
unset __GL_MaxFramesAllowed || true
nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" >/dev/null 2>&1 || true

ow_dxvk_prefix="/steam/steamapps/compatdata/2357570/pfx/drive_c/users/steamuser/AppData/Local/dxvk"
ow_nv_cache="${XDG_CACHE_HOME}/steam-shadercache/2357570/nvidiav1"
mkdir -p "$ow_dxvk_prefix" "$XDG_CONFIG_HOME/dxvk" "$ow_nv_cache"
# Use the prefix cache the game already writes (~600MiB). The extra
# ~/.cache/dxvk/overwatch dir stayed empty, so first-load compiled cold.
export DXVK_STATE_CACHE_PATH="$ow_dxvk_prefix"
export PROTON_DXVK_CONFIG_FILE="$XDG_CONFIG_HOME/dxvk/overwatch.conf"
export DXVK_CONFIG_FILE="$PROTON_DXVK_CONFIG_FILE"
export __GL_SHADER_DISK_CACHE_PATH="$ow_nv_cache"

read -r phys_w phys_h refresh _ <<<"$(game_monitor)"
# 16:9 internally (FOV 103 / 1:1 zoom). csgo-vulkan-fix stretches that
# 1920x1080 buffer onto the 2560x1080 panel. Borderless so the Xiaomi
# does not modeset 1920@120.
width=1920
height=1080
use_219=0
# User-requested lock: 205 FPS, not refresh-3 and not uncapped.
fps_cap=205

cat >"$DXVK_CONFIG_FILE" <<EOF
dxgi.syncInterval = 0
dxgi.maxFrameLatency = 2
dxvk.tearFree = False
dxvk.enableGraphicsPipelineLibrary = True
dxvk.numCompilerThreads = 3
dxvk.maxDeviceMemory = 8192
dxvk.maxSharedMemory = 3072
EOF

ini="/steam/steamapps/compatdata/2357570/pfx/drive_c/users/steamuser/Documents/Overwatch/Settings/Settings_v0.ini"
game_ini_set "$ini" "[Render.13]" "FullScreenWidth" "\"${width}\""
game_ini_set "$ini" "[Render.13]" "FullScreenHeight" "\"${height}\""
game_ini_set "$ini" "[Render.13]" "WindowedWidth" "\"${width}\""
game_ini_set "$ini" "[Render.13]" "WindowedHeight" "\"${height}\""
game_ini_set "$ini" "[Render.13]" "FullScreenRefresh" "\"${refresh}\""
game_ini_set "$ini" "[Render.13]" "WindowedRefresh" "\"${refresh}\""
game_ini_set "$ini" "[Render.13]" "Use219AspectRatio" "\"${use_219}\""
# Borderless 1920x1080. Exclusive 1920 modeset drops the Xiaomi to 120Hz.
game_ini_set "$ini" "[Render.13]" "FullscreenWindow" "\"1\""
game_ini_set "$ini" "[Render.13]" "FullscreenWindowEnabled" "\"1\""
game_ini_set "$ini" "[Render.13]" "FieldOfView" "\"103.000000\""
game_ini_set "$ini" "[Render.13]" "HorizontalFOV" "\"103.000000\""
game_ini_set "$ini" "[Render.13]" "AADetail" "\"2\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginBottom" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginLeft" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginRight" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginTop" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "LimitToRefresh" "\"0\""
game_ini_set "$ini" "[Render.13]" "UseVSync" "\"0\""
game_ini_set "$ini" "[Render.13]" "FrameRateCap" "\"${fps_cap}\""
game_ini_set "$ini" "[Render.13]" "ReduceBuffering" "\"0\""
game_ini_set "$ini" "[Render.13]" "CpuForceSyncEnabled" "\"0\""
game_ini_set "$ini" "[Render.13]" "NVIDIAReflex" "\"0\""
game_ini_set "$ini" "[Render.13]" "ReflexMode" "\"0\""
game_ini_set "$ini" "[Input.1]" "HighTickInput" "\"1\""

game_wine_warp "/steam/steamapps/compatdata/2357570/pfx/user.reg" disable
game_x_primary "$phys_w" "$phys_h"
game_strip_overlay
game_place_overwatch

if command -v gamemoderun >/dev/null 2>&1; then
  exec gamemoderun "$@"
fi
exec "$@"
