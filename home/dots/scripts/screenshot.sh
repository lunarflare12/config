#!/usr/bin/env bash
set -euo pipefail

SCREENSHOT_DIR="${HYPRSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$SCREENSHOT_DIR"

MODE="${1:-region}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SCREENSHOT_PATH="$SCREENSHOT_DIR/screenshot_${TIMESTAMP}.png"

# Old hyprpicker used -z to freeze the screen. Current hyprpicker -z is
# --no-zoom on the color picker, which steals the pointer from slurp.
pkill -x slurp >/dev/null 2>&1 || true
pkill -x hyprpicker >/dev/null 2>&1 || true

cleanup() {
  pkill -x slurp >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM HUP

edit() {
  local src=$1
  hyprctl dispatch focusmonitor DP-1 >/dev/null 2>&1 || true
  satty \
    --filename "$src" \
    --output-filename "$SCREENSHOT_PATH" \
    --fullscreen current-screen \
    --early-exit all \
    --copy-command wl-copy \
    --actions-on-enter save-to-clipboard,save-to-file \
    --actions-on-escape save-to-clipboard,exit \
    --floating-hack \
    --no-window-decoration \
    --initial-tool crop
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

capture() {
  grim "$@" "$SCREENSHOT_PATH"
  wl-copy -t image/png < "$SCREENSHOT_PATH" >/dev/null 2>&1 || true
  edit "$SCREENSHOT_PATH"
}

case "$MODE" in
  region | annotate | region-edit | edit)
    geo=$(slurp -d) || exit 0
    [[ -n "$geo" ]] || exit 0
    capture -g "$geo"
    ;;
  window)
    point=$(slurp -p -f '%x,%y') || exit 0
    [[ -n "$point" ]] || exit 0
    px=${point%%,*}
    py=${point##*,}
    geo=$(window_at_point "$px" "$py")
    if [[ -z "$geo" ]]; then
      geo=$(hyprctl -j activewindow | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    fi
    capture -g "$geo"
    ;;
  output | monitor-active | screen)
    out=$(focused_output)
    if [[ -n "$out" ]]; then
      capture -o "$out"
    else
      capture
    fi
    ;;
  *)
    echo "Usage: $(basename "$0") <region|window|output>" >&2
    exit 1
    ;;
esac
