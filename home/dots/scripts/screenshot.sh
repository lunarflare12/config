#!/usr/bin/env bash
set -euo pipefail

SCREENSHOT_DIR="${HYPRSHOT_DIR:-$HOME/Pictures/Screenshots}"
mkdir -p "$SCREENSHOT_DIR"

MODE="${1:-region}"
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
FILENAME="screenshot_${TIMESTAMP}.png"
SCREENSHOT_PATH="$SCREENSHOT_DIR/$FILENAME"

cleanup_freeze() {
  pkill -x hyprpicker 2>/dev/null || true
  pkill -x slurp 2>/dev/null || true
}

trap 'cleanup_freeze' EXIT INT TERM HUP

copy_to_clipboard() {
  wl-copy --type image/png < "$1"
}

notify_success() {
  notify-send --icon="$1" --app-name="Screenshot" --urgency=low --expire-time=4000 "Screenshot saved" "$(basename "$1")"
}

run_hyprshot() {
  hyprshot "$@" --silent --output-folder "$SCREENSHOT_DIR" --filename "$FILENAME"
  local code=$?
  cleanup_freeze
  return "$code"
}

case "$MODE" in
  region) run_hyprshot -m region --freeze ;;
  window) run_hyprshot -m window --freeze ;;
  output | monitor-active) run_hyprshot -m output -m active --freeze ;;
  region-clipboard | region-copy)
    run_hyprshot -m region --freeze
    if [[ -f "$SCREENSHOT_PATH" ]]; then
      copy_to_clipboard "$SCREENSHOT_PATH"
      notify_success "$SCREENSHOT_PATH"
    fi
    exit 0
    ;;
  annotate | region-edit | edit)
    cleanup_freeze
    # Flameshot draws its own pointer/crosshair (slurp/Hyprland software
    # cursors stay invisible on the selection overlay with Nvidia).
    # Annotation tools: pen, marker, text, shapes — editor is a normal window.
    flameshot gui -p "$SCREENSHOT_PATH" -c
    if [[ -f "$SCREENSHOT_PATH" ]]; then
      notify_success "$SCREENSHOT_PATH"
    fi
    exit 0
    ;;
  *)
    echo "Usage: $(basename "$0") <region|window|output|region-clipboard|annotate>" >&2
    exit 1
    ;;
esac

if [[ -f "$SCREENSHOT_PATH" ]]; then
  notify_success "$SCREENSHOT_PATH"
fi
