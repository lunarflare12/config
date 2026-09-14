#!/usr/bin/env bash
# Super+X. Prefer the Quickshell power list (same surface as the app launcher).
set -euo pipefail
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin:${PATH:-}"

if command -v qs >/dev/null 2>&1 && qs ipc call power toggle >/dev/null 2>&1; then
  exit 0
fi

choice=$(echo -e "󰐥 Shutdown\n󰜉 Reboot\n󰌢 Reboot to BIOS\n󰍃 Logout\n󰌾 Lock\n󰤄 Sleep" | fuzzel --dmenu)
case "$choice" in
  "󰐥 Shutdown") systemctl poweroff ;;
  "󰜉 Reboot") systemctl reboot ;;
  "󰌢 Reboot to BIOS") systemctl reboot --firmware-setup ;;
  "󰍃 Logout") loginctl terminate-session "${XDG_SESSION_ID:-}" ;;
  "󰌾 Lock") loginctl lock-session ;;
  "󰤄 Sleep") systemctl suspend ;;
esac
