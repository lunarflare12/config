#!/bin/sh
# Chrome/Firefox inside the box. Telegram links go to the host client;
# local files and folders open host Finder.
url="${1:-}"
[ -n "$url" ] || exit 0
mkdir -p "${HOME}/ipc"

case "$url" in
  tg:*|telegram:*|tonsite:*|https://t.me/*|https://t.me|http://t.me/*|https://telegram.me/*|https://telegram.dog/*)
    printf '%s\n' "$url" > "${HOME}/ipc/telegram.url"
    exit 0
    ;;
esac

case "$url" in
  file:*|/*|~/*)
    ipc="${HOME}/ipc"
    mkdir -p "$ipc"
    tmp=$(mktemp "$ipc/open.path.XXXXXX")
    printf '%s\n' "$url" > "$tmp"
    mv -f "$tmp" "$ipc/open.path"
    ;;
esac
exit 0
