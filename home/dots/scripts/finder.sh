#!/usr/bin/env bash
# Thunar as macOS Finder. Follow the session theme (WhiteSur-Dark).
set -euo pipefail

xfq=/run/current-system/sw/bin/xfconf-query
if [[ -x $xfq ]]; then
  "$xfq" -c thunar -p /last-side-pane -s ThunarShortcutsPane >/dev/null 2>&1 || true
  "$xfq" -c thunar -p /last-separator-position -s 220 >/dev/null 2>&1 || true
  "$xfq" -c thunar -p /last-menubar-visible -s false >/dev/null 2>&1 || true
  "$xfq" -c thunar -p /last-location-bar -s ThunarLocationButtons >/dev/null 2>&1 || true
fi

thunar_bin=/run/current-system/sw/bin/thunar
if [[ ! -x $thunar_bin ]]; then
  thunar_bin=$(command -v thunar)
fi

exec "$thunar_bin" "$@"
