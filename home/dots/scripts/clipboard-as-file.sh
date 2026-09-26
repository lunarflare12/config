#!/usr/bin/env bash
# Stage one copied file into Telegram's inbox and offer that path as a file.
# Telegram never sees Chrome/Downloads trees — only ~/Downloads/telegram-1.
set -euo pipefail

export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER:-dd}/bin:${PATH:-}"

stamp="${XDG_RUNTIME_DIR:-/run/user/1000}/aurora-clip-file"
inbox="${HOME}/Downloads/telegram-1"
boxes=(chrome-dd chrome-az chrome-hika chrome-sciencesoft firefox zen)

have() { command -v "$1" >/dev/null 2>&1; }
have wl-paste && have wl-copy || exit 0

types=$(wl-paste -l 2>/dev/null || true)
[[ -n $types ]] || exit 0
echo "$types" | grep -qiE '^(image/|text/html)' && exit 0

raw=""
if echo "$types" | grep -qx 'text/uri-list'; then
  raw=$(wl-paste -t text/uri-list -n 2>/dev/null || true)
fi
if [[ -z $raw ]]; then
  raw=$(wl-paste -n 2>/dev/null || true)
fi
raw=${raw//$'\r'/}
raw=${raw%%$'\n'*}
[[ -n $raw ]] || exit 0

case "$raw" in
  http://*|https://*|tg:*|telegram:*) exit 0 ;;
  file:///home/telegram/Downloads/*) exit 0 ;;
esac

path=$raw
path=${path#file://localhost}
path=${path#file://}
if [[ $path == *%* ]]; then
  path=$(python3 -c 'import sys,urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$path")
fi

# Already the inbox copy — do not restage.
case "$path" in
  "${inbox}"/*|/home/telegram/Downloads/*) exit 0 ;;
esac

host=""
name=$(basename -- "$path")
[[ -n $name && $name != / && $name != . && $name != .. ]] || exit 0

if [[ $path == /home/app/Downloads/* ]]; then
  cand="${HOME}/Downloads/${path#/home/app/Downloads/}"
  if [[ -f $cand ]]; then
    host=$cand
  else
    for box in "${boxes[@]}"; do
      cand="${HOME}/programs/${box}/Downloads/${name}"
      if [[ -f $cand ]]; then
        host=$cand
        break
      fi
    done
  fi
elif [[ -f $path ]]; then
  host=$path
fi
[[ -n $host ]] || exit 0
host=$(readlink -f -- "$host")
[[ -f $host ]] || exit 0

# Refuse staging anything outside the user's home.
case "$host" in
  "${HOME}"/*) ;;
  *) exit 0 ;;
esac

if [[ -f $stamp ]] && [[ $(cat "$stamp") == "$host" ]]; then
  exit 0
fi

mkdir -p "$inbox"
# Never put a symlink/mount into the inbox — copy bytes only.
cp -f -- "$host" "$inbox/$name"
chmod 600 "$inbox/$name" 2>/dev/null || true

# Path Telegram can open inside its box. Host apps do not need this offer.
printf 'file:///home/telegram/Downloads/%s\n' "$name" | wl-copy --type text/uri-list
printf '%s' "$host" > "$stamp"
