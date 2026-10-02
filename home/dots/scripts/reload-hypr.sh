#!/bin/sh
# Do not restart quickshell here. That tears down layer-shell and
# SIGTRAPs Electron apps (Cursor) on this NVIDIA setup.
hyprctl reload
