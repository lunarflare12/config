#!/bin/sh
url="${1:-}"
case "$url" in
  tg:*|telegram:*|tonsite:*|https://t.me/*|https://t.me|http://t.me/*|https://telegram.me/*|https://telegram.dog/*)
    mkdir -p "${HOME}/ipc"
    printf '%s\n' "$url" > "${HOME}/ipc/telegram.url"
    ;;
esac
exit 0
