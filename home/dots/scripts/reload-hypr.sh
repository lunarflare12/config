#!/bin/sh
# Do not restart quickshell here. That tears down layer-shell and
# SIGTRAPs Electron apps (Cursor) on this NVIDIA setup.
hyprctl reload
"${HOME:-/home/dd}/.config/scripts/ow-stretch-plugin.sh" >/dev/null 2>&1 || true
