#!/usr/bin/env bash
# Host launcher: Overwatch runs in containers/steam service `overwatch`.
# Steam launch options (inside the box): /home/dd/.config/scripts/overwatch.sh %command%
set -euo pipefail

HOME="${HOME:-/home/dd}"
COMPOSE="${HOME}/containers/steam/compose.yml"
# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

in_box=0
if [ -n "${STEAM_CONTAINER:-}" ] || [ -f /.dockerenv ]; then
  in_box=1
fi

# ── Host path: only docker; never run Proton/OW on the host. ─────────────
if [ "$in_box" -eq 0 ]; then
  if [ -x "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" ]; then
    "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" >/dev/null 2>&1 || true
  fi

  # One library lock: Steam UI, Terraria and Albion must be down.
  game_ensure_xwayland
  game_stop_other_boxes overwatch
  game_gpu_perf
  game_compositor_game 1

  mkdir -p "${HOME}/programs/steam"
  # Foreground: container lives for the Steam silent + game session.
  docker compose -f "$COMPOSE" run --rm --name overwatch overwatch
  status=$?
  game_compositor_game 0
  exit "$status"
fi

# ── Inside overwatch/steam box (launch options %command%). ───────────────

if game_host pgrep -a Hyprland 2>/dev/null | grep -q -- '--safe-mode'; then
  notify-send -u critical "Overwatch" "Hyprland в safe-mode — перезапусти композитор" 2>/dev/null || true
  echo "overwatch.sh: Hyprland --safe-mode; aborting" >&2
  exit 1
fi

game_block_fossilize
game_low_latency

# Do not call gamemode-start / gamemoderun: aurora-game toggles kill HDMI,
# hyprsunset, and decorations — user wants both monitors untouched.
if [ -x "${BASH_SOURCE[0]%/*}/ow-stretch-plugin.sh" ]; then
  "${BASH_SOURCE[0]%/*}/ow-stretch-plugin.sh" load >/dev/null 2>&1 || true
fi
game_compositor_game 1

# ── Flags from ProtonDB + DXVK#3813 + Valve/NVIDIA OW shader-cache reports ──
# https://www.protondb.com/app/2357570
# https://github.com/doitsujin/dxvk/issues/3813
# https://github.com/ValveSoftware/steam-for-linux/issues/11392
export PROTON_ENABLE_NVAPI="${PROTON_ENABLE_NVAPI:-1}"
export PROTON_HIDE_NVIDIA_GPU="${PROTON_HIDE_NVIDIA_GPU:-0}"
export PROTON_ENABLE_NGX_UPDATER=0
export PROTON_LOCAL_SHADER_CACHE=1
export DXVK_NVAPI_VKREFLEX=0
unset ENABLE_VK_LAYER_VALVE_steam_fossilize_1 || true
export DISABLE_VK_LAYER_VALVE_steam_fossilize_1=1
# No /dev/ntsync on this host — fsync/esync only.
export PROTON_NO_NTSYNC=1
export WINEFSYNC=1
export WINEESYNC=1
export PROTON_NO_ESYNC=0
export PROTON_NO_FSYNC=0
export PROTON_NO_XALIA=1
export PROTON_USE_XALIA=0
export DXVK_FILTER_DEVICE_NAME="${DXVK_FILTER_DEVICE_NAME:-NVIDIA}"
if [ -f /run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json ]; then
  export VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
  export VK_ICD_FILENAMES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json
fi
# Stay on X11 + stretch. NVIDIA's default EGL list puts wayland2 first;
# then the game presents off Hyprland's Xwayland and the GPU stays in P3.
unset WAYLAND_DISPLAY GBM_BACKEND NVD_BACKEND || true
export PROTON_ENABLE_WAYLAND=0
export SDL_VIDEODRIVER=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
egl_x11="/run/opengl-driver/share/egl/egl_external_platform.d"
if [ -f "$egl_x11/20_nvidia_xlib.json" ]; then
  export __EGL_EXTERNAL_PLATFORM_CONFIG_FILENAMES="$egl_x11/20_nvidia_xlib.json:$egl_x11/20_nvidia_xcb.json"
fi
export DXVK_HDR=0
export DXVK_STATE_CACHE=1
export __GL_SYNC_TO_VBLANK=0
export __GL_SYNC_DISPLAY_DEVICE="${__GL_SYNC_DISPLAY_DEVICE:-DP-1}"
export __GL_SHARPEN_ENABLE=0
export __GL_GSYNC_ALLOWED=0
export __GL_VRR_ALLOWED=0
unset __GL_MaxFramesAllowed || true
# Steam overlay Vulkan layer was on and compositing every frame.
unset ENABLE_VK_LAYER_VALVE_steam_overlay_1 || true
export DISABLE_VK_LAYER_VALVE_steam_overlay_1=1
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1

XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

ow_dxvk_home="${XDG_CACHE_HOME}/dxvk/overwatch"
ow_dxvk_prefix="/steam/steamapps/compatdata/2357570/pfx/drive_c/users/steamuser/AppData/Local/dxvk"
# Steam's shader manager truncates steamapps/shadercache on every launch.
# This tree is a separate copy (merged 4.3G + session 3.6G). Same filenames,
# so the driver opens them instead of compiling a new cache.
ow_nv_cache="${XDG_CACHE_HOME}/nvidia/overwatch"
mkdir -p "$ow_dxvk_home" "$ow_dxvk_prefix" "$XDG_CONFIG_HOME/dxvk" "$ow_nv_cache"
if [ -x "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" ]; then
  "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" >/dev/null 2>&1 || true
fi
export DXVK_STATE_CACHE_PATH="$ow_dxvk_home"
export PROTON_DXVK_CONFIG_FILE="$XDG_CONFIG_HOME/dxvk/overwatch.conf"
export DXVK_CONFIG_FILE="$PROTON_DXVK_CONFIG_FILE"
export __GL_SHADER_DISK_CACHE_PATH="$ow_nv_cache"
export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export __GL_SHADER_DISK_CACHE_SIZE="${__GL_SHADER_DISK_CACHE_SIZE:-34359738368}"
export __GL_SHADER_DISK_CACHE_APP_NAME=steamapp_shader_cache
export __GL_SHADER_DISK_CACHE_READ_ONLY_APP_NAME="steam_shader_cache;steamapp_merged_shader_cache"

read -r phys_w phys_h refresh _ <<<"$(game_monitor)"
width=1920
height=1080
use_219=0
# 300 on a 200Hz XWayland compositor hitchs 1% lows and keeps the GPU in P3.
fps_cap=${refresh:-200}
if [ "$fps_cap" -lt 60 ]; then
  fps_cap=200
fi
export DXVK_FRAME_RATE="$fps_cap"

# trackPipelineLifetime: OW D3D11 RAM blow-up under GPL (dxvk#3813), ProtonDB default tip.
# Leave numCompilerThreads at DXVK default (all cores). Do not cap device memory.
cat >"$DXVK_CONFIG_FILE" <<EOF
dxgi.syncInterval = 0
dxvk.trackPipelineLifetime = True
EOF

ini="/steam/steamapps/compatdata/2357570/pfx/drive_c/users/steamuser/Documents/Overwatch/Settings/Settings_v0.ini"
game_ini_set "$ini" "[Render.13]" "FullScreenWidth" "\"${width}\""
game_ini_set "$ini" "[Render.13]" "FullScreenHeight" "\"${height}\""
game_ini_set "$ini" "[Render.13]" "WindowedWidth" "\"${width}\""
game_ini_set "$ini" "[Render.13]" "WindowedHeight" "\"${height}\""
game_ini_set "$ini" "[Render.13]" "FullScreenRefresh" "\"${refresh}\""
game_ini_set "$ini" "[Render.13]" "WindowedRefresh" "\"${refresh}\""
game_ini_set "$ini" "[Render.13]" "Use219AspectRatio" "\"${use_219}\""
game_ini_set "$ini" "[Render.13]" "FullscreenWindow" "\"1\""
game_ini_set "$ini" "[Render.13]" "FullscreenWindowEnabled" "\"1\""
game_ini_set "$ini" "[Render.13]" "FieldOfView" "\"103.000000\""
game_ini_set "$ini" "[Render.13]" "HorizontalFOV" "\"103.000000\""
game_ini_set "$ini" "[Render.13]" "AADetail" "\"1\""
game_ini_set "$ini" "[Render.13]" "ModelQuality" "\"2\""
game_ini_set "$ini" "[Render.13]" "PhysicsQuality" "\"1\""
game_ini_set "$ini" "[Render.13]" "HighQualityUpsample" "\"0\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginBottom" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginLeft" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginRight" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "BroadcastMarginTop" "\"1.000000\""
game_ini_set "$ini" "[Render.13]" "LimitToRefresh" "\"0\""
game_ini_set "$ini" "[Render.13]" "UseVSync" "\"0\""
game_ini_set "$ini" "[Render.13]" "FrameRateCap" "\"${fps_cap}\""
game_ini_set "$ini" "[Render.13]" "ReduceBuffering" "\"0\""
game_ini_set "$ini" "[Render.13]" "TripleBufferingEnabled" "\"0\""
game_ini_set "$ini" "[Render.13]" "CpuForceSyncEnabled" "\"0\""
game_ini_set "$ini" "[Render.13]" "NVIDIAReflex" "\"0\""
game_ini_set "$ini" "[Render.13]" "ReflexMode" "\"0\""
game_ini_set "$ini" "[Render.13]" "ImageSharpening" "\"0.000000\""
# OW mirrors some Render keys into TankMenuItems; the spaced copy was
# capping at 205 while Render said 300.
game_ini_set "$ini" "[TankMenuItems.1]" "FrameRateCap" "\"${fps_cap}\""
game_ini_set "$ini" "[TankMenuItems.1]" "UseVSync" "\"0\""
game_ini_set "$ini" "[TankMenuItems.1]" "LimitToRefresh" "\"0\""
game_ini_set "$ini" "[Input.1]" "HighTickInput" "\"1\""

game_wine_warp "/steam/steamapps/compatdata/2357570/pfx/user.reg" disable
game_xwayland_ultrawide
game_x_primary "$phys_w" "$phys_h"
game_strip_overlay
game_place_overwatch

if [ "$#" -eq 0 ]; then
  echo "overwatch.sh: inside box but no command" >&2
  exit 1
fi

# Prefer D3D11→DXVK (ProtonDB); skip if user/Steam already passed -dx11/-dx12.
has_dx=0
for a in "$@"; do
  case "$a" in
  -dx11 | -dx12) has_dx=1 ;;
  esac
done
if [ "$has_dx" -eq 0 ]; then
  set -- "$@" -dx11
fi

"$@"
status=$?
# Game process is gone. Unload stretch once and tell the silent Steam
# client to exit so the container does not sit there reloading the plugin.
"${BASH_SOURCE[0]%/*}/ow-stretch-plugin.sh" unload >/dev/null 2>&1 || true
steam -shutdown >/dev/null 2>&1 || true
exit "$status"
