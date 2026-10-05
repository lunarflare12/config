#!/usr/bin/env bash
# Force Overwatch's X11 surface to 1920×1080 (16:9). Hyprland stretches
# that onto the 2560×1080@200 panel. Do not unload while the game is mapped.
set -euo pipefail

HYPRCTL="${HYPRCTL:-hyprctl}"
HOME_DIR="${HOME:-/home/dd}"
CFG="${XDG_CONFIG_HOME:-$HOME_DIR/.config}/hypr"
DIR_FILE="$CFG/hypr-csgo-vulkan-fix-dir"

APP_CLASS="${CSGO_VKFIX_CLASS:-steam_app_2357570}"
FAKE_W="${CSGO_VKFIX_W:-1920}"
FAKE_H="${CSGO_VKFIX_H:-1080}"

resolve_so() {
  if [ -f "$DIR_FILE" ]; then
    dir=$(tr -d '\n' <"$DIR_FILE")
    for cand in "$dir/lib/libcsgo-vulkan-fix.so" "$dir/lib/csgo-vulkan-fix.so"; do
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
  "$HYPRCTL" plugin list 2>/dev/null | grep -qi 'csgo-vulkan-fix'
}

configure() {
  "$HYPRCTL" eval "(function()
    hl.config({
      plugin = {
        csgo_vulkan_fix = {
          fix_mouse = true,
        },
      },
    })
    hl.plugin.csgo_vulkan_fix.vkfix_app({
      app = '${APP_CLASS}',
      w = ${FAKE_W},
      h = ${FAKE_H},
    })
    if _G.aurora_vkfix_reload then
      pcall(function()
        _G.aurora_vkfix_reload:remove()
      end)
    end
    _G.aurora_vkfix_reload = hl.on('config.reloaded', function()
      pcall(function()
        hl.plugin.csgo_vulkan_fix.vkfix_app({
          app = '${APP_CLASS}',
          w = ${FAKE_W},
          h = ${FAKE_H},
        })
      end)
    end)
    return true
  end)()" >/dev/null
}

case "${1:-ensure}" in
ensure | load)
  so=$(resolve_so) || {
    echo "hypr-csgo-vulkan-fix: plugin .so not found (rebuild home-manager)" >&2
    exit 1
  }
  if ! plugin_loaded; then
    "$HYPRCTL" plugin load "$so" >/dev/null
  fi
  configure
  ;;
reload)
  plugin_loaded || exec "$0" ensure
  configure
  ;;
unload)
  echo "hypr-csgo-vulkan-fix: unload refused (crashes Hyprland under Overwatch)" >&2
  exit 1
  ;;
*)
  echo "usage: $0 {ensure|load|reload}" >&2
  exit 2
  ;;
esac
