#!/usr/bin/env bash
set -euo pipefail
DEV="${INSTA360_DEV:-/dev/video0}"
LOOK="${1:-natural}"
case "$LOOK" in
  natural|0) B=52; C=54; S=48; SH=42; AWB=1; BL=0; WB=5600 ;;
  stream|1)  B=55; C=58; S=50; SH=48; AWB=1; BL=1; WB=5600 ;;
  soft|2)    B=56; C=46; S=44; SH=32; AWB=0; BL=0; WB=4800 ;;
  desk|3)    B=50; C=62; S=38; SH=58; AWB=1; BL=0; WB=5600 ;;
  *) echo "usage: insta360-look.sh [natural|stream|soft|desk]" >&2; exit 1 ;;
esac
v4l2-ctl -d "$DEV" --set-ctrl=brightness="$B" --set-ctrl=contrast="$C" --set-ctrl=saturation="$S" --set-ctrl=sharpness="$SH" --set-ctrl=white_balance_automatic="$AWB" >/dev/null
[ "$AWB" = 0 ] && v4l2-ctl -d "$DEV" --set-ctrl=white_balance_temperature="$WB" >/dev/null || true
v4l2-ctl -d "$DEV" --set-ctrl=backlight_compensation="$BL" >/dev/null 2>&1 || true
v4l2-ctl -d "$DEV" --set-ctrl=focus_automatic_continuous=1 >/dev/null 2>&1 || true
echo "Insta360 look: $LOOK (b=$B c=$C s=$S sh=$SH)"
