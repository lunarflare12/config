#!/usr/bin/env bash
set -euo pipefail

iDIR="${HOME}/.config/swaync/icons"

get_backlight() {
  max=$(brightnessctl max)
  light=$(brightnessctl get)
  echo $((100 * light / max))%
}

get_icon() {
  current=${1%%%}
  if [[ "$current" -le 20 ]]; then
    echo "${iDIR}/brightness-20.png"
  elif [[ "$current" -le 40 ]]; then
    echo "${iDIR}/brightness-40.png"
  elif [[ "$current" -le 60 ]]; then
    echo "${iDIR}/brightness-60.png"
  elif [[ "$current" -le 80 ]]; then
    echo "${iDIR}/brightness-80.png"
  else
    echo "${iDIR}/brightness-100.png"
  fi
}

notify_user() {
  level=$(get_backlight)
  icon=$(get_icon "${level%%%}")
  notify-send -h string:x-canonical-private-synchronous:sys-notify \
    -u low -i "$icon" "Brightness: ${level}"
}

case "${1:-}" in
  --get) get_backlight ;;
  --inc)
    brightnessctl set 5%+
    notify_user
    ;;
  --dec)
    brightnessctl set 5%-
    notify_user
    ;;
  *) get_backlight ;;
esac
