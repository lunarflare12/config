#!/usr/bin/env bash
set -euo pipefail

SCREENSHOT_DIR="${HYPRSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$SCREENSHOT_DIR"

MODE="${1:-region}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="screenshot_${TIMESTAMP}.png"
SCREENSHOT_PATH="$SCREENSHOT_DIR/$FILENAME"

freeze_pid=""

cleanup() {
  if [[ -n "${freeze_pid}" ]]; then
    kill "${freeze_pid}" 2>/dev/null || true
  fi
  pkill -x hyprpicker 2>/dev/null || true
  pkill -x slurp 2>/dev/null || true
}

trap cleanup EXIT INT TERM HUP

freeze() {
  hyprpicker -r -z >/dev/null 2>&1 &
  freeze_pid=$!
  sleep 0.05
}

thaw() {
  if [[ -n "${freeze_pid}" ]]; then
    kill "${freeze_pid}" 2>/dev/null || true
    freeze_pid=""
  fi
  pkill -x hyprpicker 2>/dev/null || true
}

edit() {
  local src=$1
  thaw
  satty \
    --filename "$src" \
    --output-filename "$SCREENSHOT_PATH" \
    --early-exit all \
    --copy-command wl-copy \
    --actions-on-enter save-to-clipboard \
    --actions-on-enter save-to-file \
    --actions-on-escape save-to-clipboard \
    --actions-on-escape exit \
    --fullscreen current \
    --notification-thumbnail screenshot \
    --disable-notifications
}

focused_output() {
  hyprctl -j monitors | jq -r '.[] | select(.focused == true) | .name' | head -n 1
}

window_at_point() {
  local px=$1 py=$2
  hyprctl -j clients | jq -r --argjson x "$px" --argjson y "$py" '
    .[]
    | select(.mapped == true and .hidden == false and (.workspace.id // 0) > 0)
    | select($x >= .at[0] and $y >= .at[1] and $x < (.at[0] + .size[0]) and $y < (.at[1] + .size[1]))
    | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"
  ' | head -n 1
}

case "$MODE" in
  region | annotate | region-edit | edit)
    freeze
    geo=$(slurp) || exit 1
    grim -g "$geo" "$SCREENSHOT_PATH"
    edit "$SCREENSHOT_PATH"
    ;;
  window)
    freeze
    point=$(slurp -p -f '%x,%y') || exit 1
    px=${point%%,*}
    py=${point##*,}
    geo=$(window_at_point "$px" "$py")
    if [[ -z "$geo" ]]; then
      geo=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    fi
    grim -g "$geo" "$SCREENSHOT_PATH"
    edit "$SCREENSHOT_PATH"
    ;;
  output | monitor-active | screen)
    out=$(focused_output)
    grim ${out:+-o "$out"} "$SCREENSHOT_PATH"
    edit "$SCREENSHOT_PATH"
    ;;
  *)
    echo "Usage: $(basename "$0") <region|window|output>" >&2
    exit 1
    ;;
esac
