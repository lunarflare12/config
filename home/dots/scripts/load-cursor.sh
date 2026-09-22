#!/usr/bin/env bash
# Restore the last Aurora cursor after login.
set -euo pipefail

state_dir="${XDG_CACHE_HOME:-$HOME/.cache}/aurora"
id_file="$state_dir/current-cursor"
size_file="$state_dir/current-cursor-size"
id="macos"
size="${AURORA_CURSOR_SIZE:-24}"

if [[ -f "$id_file" ]]; then
  id="$(tr -d '\r\n' < "$id_file")"
fi
if [[ -f "$size_file" ]]; then
  size="$(tr -d '\r\n' < "$size_file")"
fi
[[ -n "$id" ]] || id="macos"
[[ -n "$size" ]] || size=24

exec "$HOME/.config/scripts/set-cursor.sh" "$id" "$size"
