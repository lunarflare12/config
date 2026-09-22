#!/usr/bin/env bash
# Stretch plugin is compositor-global. Keep it loaded only while
# Overwatch is on the active workspace. Otherwise Steam (already open
# on another desktop) gets a fake 2560x1440 buffer.
set +e
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin:${PATH:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
unset LD_PRELOAD LD_LIBRARY_PATH STEAM_RUNTIME_LIBRARY_PATH || true

HOME="${HOME:-/home/dd}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPRCTL="${HYPRCTL:-/run/current-system/sw/bin/hyprctl}"
STATE="${HOME}/.local/state/aurora-vkfix-so"
# User-built overlay (nix build of the patched main.cpp) beats the stale
# HM path that still has the old mouse formula until nixos-rebuild.
LOCAL_SO="${HOME}/.local/lib/hypr/libcsgo-vulkan-fix.so"
mkdir -p "${HOME}/.local/state"

if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "${XDG_RUNTIME_DIR}/hypr" ]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(find "${XDG_RUNTIME_DIR}/hypr" -maxdepth 1 -mindepth 1 -printf '%T@ %f\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  export HYPRLAND_INSTANCE_SIGNATURE
fi
[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || exit 0

# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

find_so() {
  local dirf="${XDG_CONFIG_HOME}/hypr/ow-vkfix-dir" dir cand
  for cand in "$LOCAL_SO"; do
    if [ -f "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  if [ -f "$STATE" ]; then
    cand=$(tr -d '[:space:]' <"$STATE")
    if [ -f "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
    fi
  fi
  if [ -f "$dirf" ]; then
    dir=$(tr -d '[:space:]' <"$dirf")
    for cand in "$dir/lib/libcsgo-vulkan-fix.so" "$dir/lib/hyprland/libcsgo-vulkan-fix.so"; do
      if [ -f "$cand" ]; then
        printf '%s\n' "$cand"
        return 0
      fi
    done
  fi
  for cand in /nix/store/*csgo-vulkan-fix*/lib/libcsgo-vulkan-fix.so; do
    if [ -f "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

plugin_loaded() {
  "$HYPRCTL" plugin list 2>/dev/null | grep -q 'csgo-vulkan-fix'
}

set_expand() {
  local on="$1"
  "$HYPRCTL" eval "hl.config({ render = { expand_undersized_textures = ${on} } })" >/dev/null 2>&1 || true
}

unload() {
  set_expand false
  plugin_loaded || true
  local so cand
  so=$(find_so || true)
  if [ -n "$so" ]; then
    "$HYPRCTL" plugin unload "$so" >/dev/null 2>&1 || true
  fi
  if plugin_loaded; then
    for cand in /nix/store/*csgo-vulkan-fix*/lib/libcsgo-vulkan-fix.so "$LOCAL_SO"; do
      [ -f "$cand" ] && "$HYPRCTL" plugin unload "$cand" >/dev/null 2>&1 || true
    done
  fi
  game_xwayland_restore
}

register() {
  # fix_mouse must stay on: compositor window is 2560x1080, game surface
  # is 2560x1440. The patched .so scales by res/box only.
  "$HYPRCTL" eval '
if hl.plugin and hl.plugin.csgo_vulkan_fix and hl.plugin.csgo_vulkan_fix.vkfix_app then
    pcall(function()
        hl.config({
            plugin = { csgo_vulkan_fix = { fix_mouse = true } },
            render = { expand_undersized_textures = true },
        })
    end)
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "steam_app_2357570", w = 2560, h = 1440 })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "overwatch.exe", w = 2560, h = 1440 })
    hl.config({ render = { expand_undersized_textures = true } })
end
' >/dev/null 2>&1 || true
}

load() {
  local so
  so=$(find_so || true)
  [ -n "$so" ] || return 0
  printf '%s\n' "$so" >"$STATE"
  game_xwayland_ultrawide
  if ! plugin_loaded; then
    "$HYPRCTL" plugin load "$so" >/dev/null 2>&1 || true
  fi
  if plugin_loaded; then
    register
  else
    set_expand false
  fi
}

# Active window is the real Overwatch client. Title "Overwatch 2" on Steam
# must not count — that used to keep the plugin loaded on the library.
ow_focused() {
  local w cls
  w=$("$HYPRCTL" activewindow -j 2>/dev/null) || return 1
  cls=$(printf '%s' "$w" | sed -n 's/.*"class": *"\([^"]*\)".*/\1/p' | head -1)
  [ -n "$cls" ] || return 1
  case "$cls" in
    steam_app_2357570 | [Oo]verwatch.exe | [Oo]verwatch) return 0 ;;
  esac
  printf '%s' "$cls" | grep -qi 'overwatch' || return 1
  printf '%s' "$cls" | grep -qi '^steam$' && return 1
  return 0
}

cmd="${1:-sync}"
case "$cmd" in
  unload)
    unload
    ;;
  --force | load)
    load
    ;;
  sync | *)
    if ow_focused; then
      load
    else
      unload
    fi
    ;;
esac
exit 0
