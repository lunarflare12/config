#!/usr/bin/env bash
# Wake Insta360 Link before the GUI so USB resume is not the first VIDIOC.
set -euo pipefail

wake() {
  local d vendor
  if command -v insta360-wake >/dev/null 2>&1; then
    sudo -n insta360-wake >/dev/null 2>&1 || true
  fi
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" ]] || continue
    vendor="$(cat "$d/idVendor" 2>/dev/null || true)"
    [[ "$vendor" == "2e1a" ]] || continue
    printf 'on\n' >"$d/power/control" 2>/dev/null || true
    printf -- '-1\n' >"$d/power/autosuspend" 2>/dev/null || true
  done
}

wake

bin=""
if [[ -x /etc/profiles/per-user/${USER}/bin/insta360linkgui ]]; then
  bin="/etc/profiles/per-user/${USER}/bin/insta360linkgui"
elif command -v insta360linkgui >/dev/null 2>&1; then
  bin="$(command -v insta360linkgui)"
fi
if [[ -z "$bin" ]]; then
  echo "insta360linkgui not found" >&2
  exit 127
fi
exec "$bin" "$@"
