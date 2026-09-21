#!/run/current-system/sw/bin/bash
if pgrep -x dota2 >/dev/null 2>&1 || pgrep -f 'net.minecraft' >/dev/null 2>&1 || pgrep -x gamescope >/dev/null 2>&1; then
  exit 0
fi

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

rm -f "${HOME}/.local/state/aurora-game"
"$QS" ipc call bar show >/dev/null 2>&1 || true
"$HYPRCTL" eval 'dofile("/home/dd/.config/hypr/config/decorations.lua")' >/dev/null 2>&1 || true
"$HYPRCTL" eval 'dofile("/home/dd/.config/hypr/config/animations.lua")' >/dev/null 2>&1 || true
"$NVSETTINGS" -a "[gpu:0]/GPUPowerMizerMode=0" >/dev/null 2>&1 || true
systemctl --user reset-failed hyprsunset.service >/dev/null 2>&1 || true
systemctl --user start hyprsunset.service >/dev/null 2>&1 || true
systemctl --user start awww.service >/dev/null 2>&1 || true
exit 0
