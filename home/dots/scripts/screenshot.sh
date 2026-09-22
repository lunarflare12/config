#!/usr/bin/env bash
set -euo pipefail

SCREENSHOT_DIR="${HYPRSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$SCREENSHOT_DIR"

MODE="${1:-region}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
SCREENSHOT_PATH="$SCREENSHOT_DIR/screenshot_${TIMESTAMP}.png"
LOCKDIR="${XDG_RUNTIME_DIR:-/tmp}/aurora-screenshot.lock.d"

# Directory lock cannot be inherited by forked wl-copy (the flock fd was).
acquire_lock() {
  local other
  if mkdir "$LOCKDIR" 2>/dev/null; then
    echo $$ >"$LOCKDIR/pid"
    return 0
  fi
  other=$(cat "$LOCKDIR/pid" 2>/dev/null || true)
  if [[ -n "$other" && -d "/proc/$other" && "$other" != "$$" ]]; then
    return 1
  fi
  rm -rf "$LOCKDIR"
  mkdir "$LOCKDIR" 2>/dev/null || return 1
  echo $$ >"$LOCKDIR/pid"
}

release_lock() {
  rm -rf "$LOCKDIR" 2>/dev/null || true
}

cleanup() {
  pkill -x slurp >/dev/null 2>&1 || true
  release_lock
}
trap cleanup EXIT INT TERM HUP

acquire_lock || exit 0

# Super/Shift still down if the bind fires on press. Slurp treats the leftover
# pointer/key edge as an instant 1x1 selection — that is the "works on try 4".
if [[ "$MODE" == region || "$MODE" == window || "$MODE" == annotate || "$MODE" == region-edit || "$MODE" == edit ]]; then
  sleep 0.25
fi

edit() {
  local src=$1
  satty \
    --filename "$src" \
    --output-filename "$SCREENSHOT_PATH" \
    --early-exit all \
    --copy-command wl-copy \
    --actions-on-enter save-to-clipboard,save-to-file \
    --actions-on-escape save-to-clipboard,exit \
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

wide_enough() {
  local geo=$1 rest w h
  rest=${geo##* }
  w=${rest%x*}
  h=${rest#*x}
  [[ "${w:-0}" -ge 8 && "${h:-0}" -ge 8 ]]
}

# First slurp often eats a phantom click. Retry once in this same invocation.
pick_region() {
  local geo
  geo=$(slurp -d) || return 1
  if [[ -n "$geo" ]] && wide_enough "$geo"; then
    printf '%s' "$geo"
    return 0
  fi
  geo=$(slurp -d) || return 1
  [[ -n "$geo" ]] && wide_enough "$geo" || return 1
  printf '%s' "$geo"
}

capture() {
  grim -c "$@" "$SCREENSHOT_PATH"
  wl-copy -t image/png <"$SCREENSHOT_PATH" >/dev/null 2>&1 || true
  edit "$SCREENSHOT_PATH"
}

case "$MODE" in
  region | annotate | region-edit | edit)
    geo=$(pick_region) || exit 0
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
