#!/usr/bin/env bash
# Report 1920x1080 to Overwatch; Hyprland stretches that buffer onto 2560x1080.
set +e
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin:${PATH:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
unset LD_PRELOAD LD_LIBRARY_PATH STEAM_RUNTIME_LIBRARY_PATH || true

HOME="${HOME:-/home/dd}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPRCTL="${HYPRCTL:-/run/current-system/sw/bin/hyprctl}"

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "${XDG_RUNTIME_DIR}/hypr" ]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(find "${XDG_RUNTIME_DIR}/hypr" -maxdepth 1 -mindepth 1 -printf '%T@ %f\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  export HYPRLAND_INSTANCE_SIGNATURE
fi
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0

so=""
dirf="${XDG_CONFIG_HOME}/hypr/ow-vkfix-dir"
if [ -f "$dirf" ]; then
  dir=$(tr -d '[:space:]' <"$dirf")
  for cand in "$dir/lib/libcsgo-vulkan-fix.so" "$dir/lib/hyprland/libcsgo-vulkan-fix.so"; do
    if [ -f "$cand" ]; then
      so=$cand
      break
    fi
  done
fi
if [ -z "$so" ]; then
  for cand in "$@"; do
    if [ -f "$cand" ]; then
      so=$cand
      break
    fi
  done
fi
if [ -z "$so" ]; then
  for cand in /nix/store/*csgo-vulkan-fix*/lib/libcsgo-vulkan-fix.so /nix/store/*csgo-vulkan-fix*/lib/hyprland/libcsgo-vulkan-fix.so; do
    if [ -f "$cand" ]; then
      so=$cand
      break
    fi
  done
fi
[ -n "$so" ] || exit 0

if ! "$HYPRCTL" plugin list 2>/dev/null | grep -q 'csgo-vulkan-fix'; then
  "$HYPRCTL" plugin load "$so" >/dev/null 2>&1 || true
fi

"$HYPRCTL" eval '
if hl.plugin and hl.plugin.csgo_vulkan_fix and hl.plugin.csgo_vulkan_fix.vkfix_app then
    hl.config({
        plugin = {
            csgo_vulkan_fix = { fix_mouse = false },
        },
    })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "steam_app_2357570", w = 1920, h = 1080 })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "overwatch.exe", w = 1920, h = 1080 })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "Overwatch", w = 1920, h = 1080 })
end
' >/dev/null 2>&1 || true
exit 0
