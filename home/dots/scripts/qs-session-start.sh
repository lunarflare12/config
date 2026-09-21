#!/usr/bin/env bash
# Hyprland has started. Start the bar via the user unit only.
# Never exec Quickshell here: systemd also starts this unit, and a second
# process draws a second panel on top of the first.
set +e

HOME="${HOME:-/home/dd}"
export HOME
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

mkdir -p "$XDG_RUNTIME_DIR"
exec 9>"$XDG_RUNTIME_DIR/aurora-qs.start.lock"
flock -n 9 || exit 0

fix="${HOME}/.config/scripts/hypr-fix-safe-mode.sh"
if [ -x "$fix" ]; then
  "$fix" >/dev/null 2>&1 || true
fi

if pgrep -x quickshell >/dev/null 2>&1; then
  exit 0
fi

systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE >/dev/null 2>&1
systemctl --user reset-failed quickshell.service >/dev/null 2>&1
systemctl --user start quickshell.service >/dev/null 2>&1

i=0
while [ "$i" -lt 25 ]; do
  if pgrep -x quickshell >/dev/null 2>&1; then
    exit 0
  fi
  st=$(systemctl --user is-active quickshell.service 2>/dev/null || true)
  case "$st" in
    active)
      exit 0
      ;;
    failed)
      systemctl --user reset-failed quickshell.service >/dev/null 2>&1
      systemctl --user start quickshell.service >/dev/null 2>&1
      ;;
  esac
  i=$((i + 1))
  sleep 0.2
done

exit 0
