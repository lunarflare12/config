#!/run/current-system/sw/bin/bash
# Called by GameMode (host). Do not stop awww — that blanks wallpapers.
# gamemoded's PATH is empty (env bash fails). Steam's libstdc++ breaks hyprctl/qs.
unset LD_PRELOAD LD_LIBRARY_PATH STEAM_RUNTIME_LIBRARY_PATH || true
export HOME="${HOME:-/home/dd}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/1000}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin"
if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && [ -d "${XDG_RUNTIME_DIR}/hypr" ]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(find "${XDG_RUNTIME_DIR}/hypr" -maxdepth 1 -mindepth 1 -printf '%T@ %f\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  export HYPRLAND_INSTANCE_SIGNATURE
fi

HYPRCTL="/run/current-system/sw/bin/hyprctl"
QS="/etc/profiles/per-user/dd/bin/qs"
NVSETTINGS="/run/current-system/sw/bin/nvidia-settings"
LOG="${HOME}/.cache/aurora/gamemode-start.log"
mkdir -p "${HOME}/.local/state" "${HOME}/.cache/aurora"
touch "${HOME}/.local/state/aurora-game"
{
  echo "ts=$(date -Iseconds) HOME=$HOME WAYLAND=$WAYLAND_DISPLAY HYPR=$HYPRLAND_INSTANCE_SIGNATURE"
  "$NVSETTINGS" -a "[gpu:0]/GPUPowerMizerMode=1" || true
  "$HYPRCTL" eval 'dofile("/home/dd/.config/hypr/config/decorations.lua")' || true
  "$HYPRCTL" eval 'dofile("/home/dd/.config/hypr/config/animations.lua")' || true
  "$HYPRCTL" eval 'hl.config({ decoration = { blur = { enabled = false } }, animations = { enabled = false }, misc = { vrr = 0, render_unfocused_fps = 205, mouse_move_focuses_monitor = false }, render = { send_content_type = true }, debug = { vfr = false, render_solitary_wo_damage = true } })' || true
  "$HYPRCTL" eval 'if _G.aurora_sync_texture_expand then _G.aurora_sync_texture_expand() end' || true
  "$QS" ipc call bar hide || true
} >"$LOG" 2>&1
systemctl --user stop hyprsunset.service >/dev/null 2>&1 || true
systemctl --user start awww.service >/dev/null 2>&1 || true
exit 0
