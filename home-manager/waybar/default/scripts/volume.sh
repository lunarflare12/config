#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  --toggle) swayosd-client --output-volume mute-toggle ;;
  --toggle-mic) swayosd-client --input-volume mute-toggle ;;
  --inc) swayosd-client --output-volume raise ;;
  --dec) swayosd-client --output-volume lower ;;
  --mic-inc) swayosd-client --input-volume raise ;;
  --mic-dec) swayosd-client --input-volume lower ;;
  *)
    echo "usage: volume.sh --toggle|--toggle-mic|--inc|--dec|--mic-inc|--mic-dec" >&2
    exit 1
    ;;
esac
