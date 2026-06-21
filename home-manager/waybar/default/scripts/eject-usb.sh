#!/usr/bin/env bash
set -euo pipefail

usb_devices=$(lsblk -npo NAME,TYPE,TRAN,LABEL,SIZE | awk '$3 == "usb" { print $1, $4, $5 }' | sed 's/ / - /')

if [[ -z "$usb_devices" ]]; then
  fuzzel --dmenu --prompt "USB: " <<<"Нет подключённых USB-накопителей" >/dev/null || true
  exit 0
fi

selected=$(echo "$usb_devices" | fuzzel --dmenu --prompt "Извлечь USB: " || true)
[[ -z "$selected" ]] && exit 0

device=$(echo "$selected" | awk '{ print $1 }')
mapfile -t parts < <(ls "${device}"* 2>/dev/null || true)

for part in "${parts[@]}"; do
  udisksctl unmount -b "$part" 2>/dev/null || true
done
udisksctl power-off -b "$device"
