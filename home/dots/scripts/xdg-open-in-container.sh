#!/bin/sh
# Inside isolated containers: hand URLs/paths to the host via ~/ipc.
# Host systemd path units pick these up (telegram-link / container-open).
set -eu

home="${HOME:-/home/app}"
ipc="${home}/ipc"
mkdir -p "$ipc"

# Qt/Telegram often exec xdg-open with an unquoted local path, so
# "…/Telegram Desktop/foo.pdf" arrives as multiple argv words.
if [ "$#" -eq 0 ]; then
  exit 0
fi
url="$*"

case "$url" in
tg:* | telegram:* | tonsite:* | https://t.me/* | https://t.me | http://t.me/* | https://telegram.me/* | https://telegram.dog/*)
  printf '%s\n' "$url" >"${ipc}/telegram.url"
  exit 0
  ;;
esac

# Open on the host. filemanager1-stub writes open.path for "Show in folder".
printf '%s\n' "$url" >"${ipc}/launch.path"
# Debug trail (host-visible): what argv Telegram actually handed us.
printf '%s\n' "$url" >"${ipc}/launch.last"
exit 0
