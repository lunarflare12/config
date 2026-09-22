#!/usr/bin/env bash
# Windows-like: Insta360 Link stays powered while the session is up.
# Opening /dev/video0 does not hold USB runtime PM. usbfs does — same as
# Windows leaving "Allow the computer to turn off this device" unchecked.
set -euo pipefail

usb_node() {
  local d bus dev
  for d in /sys/bus/usb/devices/*; do
    [[ -f "$d/idVendor" ]] || continue
    [[ "$(cat "$d/idVendor" 2>/dev/null || true)" == "2e1a" ]] || continue
    [[ -f "$d/busnum" && -f "$d/devnum" ]] || continue
    bus="$(printf '%03d' "$(cat "$d/busnum")")"
    dev="$(printf '%03d' "$(cat "$d/devnum")")"
    if [[ -e "/dev/bus/usb/${bus}/${dev}" ]]; then
      printf '%s\n' "/dev/bus/usb/${bus}/${dev}"
      return 0
    fi
  done
  return 1
}

capture_node() {
  local n
  shopt -s nullglob
  for n in /dev/v4l/by-id/usb-Insta360_*-video-index0; do
    [[ -e "$n" ]] || continue
    printf '%s\n' "$n"
    return 0
  done
  return 1
}

# Call preset from the Windows/Linux controller: tracking + head + 2x.
apply_call_preset() {
  local cap="$1"
  local ctl=""
  if command -v linkctl >/dev/null 2>&1; then
    ctl="$(command -v linkctl)"
  else
    return 0
  fi
  "$ctl" -d "$cap" tracking on >/dev/null 2>&1 || true
  "$ctl" -d "$cap" frame head >/dev/null 2>&1 || true
  "$ctl" -d "$cap" zoom 200 >/dev/null 2>&1 || true
  "$ctl" -d "$cap" pan 0 >/dev/null 2>&1 || true
  "$ctl" -d "$cap" tilt -28800 >/dev/null 2>&1 || true
  "$ctl" -d "$cap" focus auto >/dev/null 2>&1 || true
}

while true; do
  usb="$(usb_node || true)"
  if [[ -z "${usb}" ]]; then
    sleep 2
    continue
  fi
  exec 3<>"${usb}" || {
    sleep 2
    continue
  }
  cap=""
  for _ in $(seq 1 20); do
    cap="$(capture_node || true)"
    [[ -n "${cap}" ]] && break
    sleep 0.25
  done
  if [[ -n "${cap}" ]]; then
    apply_call_preset "${cap}" &
  fi
  while [[ -e "${usb}" ]]; do
    sleep 5
  done
  exec 3>&- || true
done
