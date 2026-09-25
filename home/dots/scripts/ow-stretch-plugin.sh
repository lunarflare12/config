#!/usr/bin/env bash
# Stretch plugin is compositor-global. Keep it loaded while the
# Overwatch client exists (not only while focused — alt-tab used to
# unload it and DXGI fell back to 2560 pillarboxes). Matcher is
# steam_app_2357570 only, so the Steam library is not stretched.
set +e
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin:${PATH:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
unset LD_PRELOAD LD_LIBRARY_PATH STEAM_RUNTIME_LIBRARY_PATH || true

HOME="${HOME:-/home/dd}"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
HYPRCTL="${HYPRCTL:-/run/current-system/sw/bin/hyprctl}"
STATE="${HOME}/.local/state/aurora-vkfix-so"
# Leftover local build. Used only if the flake path in ow-vkfix-dir is missing.
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
  # Flake plugin first. A leftover ~/.local .so is what used to fail
  # the load after a Hyprland bump and leave 16:9 in the middle.
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
  if [ -f "$STATE" ]; then
    cand=$(tr -d '[:space:]' <"$STATE")
    if [ -f "$cand" ]; then
      printf '%s\n' "$cand"
      return 0
    fi
  fi
  if [ -f "$LOCAL_SO" ]; then
    printf '%s\n' "$LOCAL_SO"
    return 0
  fi
  return 1
}

plugin_loaded() {
  "$HYPRCTL" plugin list 2>/dev/null | grep -q 'csgo-vulkan-fix'
}

# After unload, ignore load for a few seconds. Steam's shutdown windows
# were reloading the plugin and Hyprland toasted a restart each time.
UNLOAD_STAMP="${HOME}/.local/state/aurora-vkfix-unloaded"

unload_cooling() {
  local t now
  [ -f "$UNLOAD_STAMP" ] || return 1
  t=$(tr -d '[:space:]' <"$UNLOAD_STAMP" 2>/dev/null || echo 0)
  now=$(date +%s)
  [ $((now - ${t:-0})) -lt 8 ]
}

unload() {
  # Leaving the hook loaded with no game is what SIGSEGVs Hyprland on
  # layer commit → setFullscreenMode (watchdog --safe-mode).
  if ! plugin_loaded; then
    return 0
  fi
  local so
  so=$(find_so || true)
  [ -n "$so" ] || return 0
  "$HYPRCTL" plugin unload "$so" >/dev/null 2>&1 || true
  date +%s >"$UNLOAD_STAMP"
}

register() {
  # fix_mouse maps window-local X (2560) → game X (1920). Never pass the
  # window size as w/h — that disables remap and aim drifts. Y scale is 1.
  # expand_undersized_textures scales that 1920 buffer to the full 2560 panel.
  "$HYPRCTL" eval '
if hl.plugin and hl.plugin.csgo_vulkan_fix and hl.plugin.csgo_vulkan_fix.vkfix_app then
    pcall(function()
        hl.config({
            plugin = { csgo_vulkan_fix = { fix_mouse = true } },
            render = { expand_undersized_textures = true },
        })
    end)
    -- Client buffer is 16:9. Passing 2560 here skips the shrink and the
    -- 1920 picture stays in the middle of the ultrawide.
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "steam_app_2357570", w = 1920, h = 1080 })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "overwatch.exe", w = 1920, h = 1080 })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "Overwatch", w = 1920, h = 1080 })
end
' >/dev/null 2>&1 || true
}

load() {
  # `load` is explicit (launcher / window.open). Do not wait for the
  # client class — that race left the 1920 buffer in the middle of 2560.
  if plugin_loaded; then
    register
    return 0
  fi
  if [ "${FORCE:-0}" != 1 ] && unload_cooling; then
    return 0
  fi
  local so
  so=$(find_so || true)
  [ -n "$so" ] || return 0
  printf '%s\n' "$so" >"$STATE"
  "$HYPRCTL" plugin load "$so" >/dev/null 2>&1 || true
  if plugin_loaded; then
    register
  fi
}

# Real Overwatch client only. Title "Overwatch 2" on Steam must not count.
ow_running() {
  local cls
  cls=$("$HYPRCTL" clients -j 2>/dev/null | sed -n 's/.*"class": *"\([^"]*\)".*/\1/p')
  printf '%s\n' "$cls" | grep -qx 'steam_app_2357570' && return 0
  printf '%s\n' "$cls" | grep -qiE '^(overwatch\.exe|overwatch)$' && return 0
  return 1
}

cmd="${1:-sync}"
case "$cmd" in
  unload)
    unload
    ;;
  --force)
    FORCE=1 load
    ;;
  load)
    load
    ;;
  sync | *)
    if ow_running; then
      load
    else
      unload
    fi
    ;;
esac
exit 0
