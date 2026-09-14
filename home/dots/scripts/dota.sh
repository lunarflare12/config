#!/usr/bin/env bash
# Steam launch options:
#   /home/dd/.config/scripts/dota.sh %command%
# Native Vulkan. Do not kill fossilize here — Steam's FOZ cache has to load.
set -euo pipefail

HOME="${HOME:-/home/dd}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
# shellcheck source=/dev/null
. "${BASH_SOURCE[0]%/*}/game-lib.sh"

game_low_latency

export __GL_SHADER_DISK_CACHE=1
export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
export __GL_SHADER_DISK_CACHE_PATH="${XDG_CACHE_HOME}/steam-shadercache/570/nvidiav1"
mkdir -p "$__GL_SHADER_DISK_CACHE_PATH"
unset DISABLE_VK_LAYER_VALVE_steam_fossilize_1 || true

game_strip_overlay

if command -v gamemoderun >/dev/null 2>&1; then
  exec gamemoderun "$@"
fi
exec "$@"
