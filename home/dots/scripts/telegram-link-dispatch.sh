#!/usr/bin/env bash
set -euo pipefail
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER:-dd}/bin:${PATH:-}"

files=(
  "${HOME}/programs/telegram-1/ipc/telegram.url"
  "${HOME}/programs/chrome-dd/ipc/telegram.url"
  "${HOME}/programs/chrome-az/ipc/telegram.url"
  "${HOME}/programs/chrome-hika/ipc/telegram.url"
  "${HOME}/programs/firefox/ipc/telegram.url"
  "${HOME}/programs/zen/ipc/telegram.url"
  "${HOME}/programs/ipc/telegram.url"
)

url=""
for file in "${files[@]}"; do
  [[ -s "$file" ]] || continue
  url="$(cat "$file")"
  : > "$file"
  [[ -n "$url" ]] && break
done

[[ -n "$url" ]] || exit 0
exec Telegram -- "$url"
