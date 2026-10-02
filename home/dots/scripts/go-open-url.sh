#!/usr/bin/env bash
exec >>/tmp/go-winebrowser.log 2>&1
echo "$(date -Is) argv: $*"
url=""
for a in "$@"; do
  case "$a" in http://*|https://*) url="$a" ;; esac
done
[[ -z "$url" && $# -ge 1 ]] && url="${@: -1}"
[[ -z "$url" ]] && exit 0
if [[ "$url" == *playgenerals.online/login* ]]; then
  code=$(printf '%s' "$url" | sed -n 's/.*[?&]code=\([^&]*\).*/\1/p')
  [[ -n "$code" ]] && command -v wl-copy >/dev/null && printf '%s' "$code" | wl-copy
  command -v notify-send >/dev/null && notify-send -u critical "Generals Online" \
    "Login page Error 102. Code in clipboard: ${code:-?}. Open Discord Command Center."
  url="https://discord.playgenerals.online/"
fi
if [[ -x /home/dd/.config/scripts/google-chrome ]]; then
  /home/dd/.config/scripts/google-chrome "$url" &
else
  xdg-open "$url" &
fi
