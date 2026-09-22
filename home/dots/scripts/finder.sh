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

system_thunar=/run/current-system/sw/bin/thunar
patched_thunar="${HOME}/.local/lib/thunar-patched/bin/thunar"

if [[ -x $patched_thunar ]]; then
  thunar_bin=$patched_thunar
  if [[ -z ${THUNARX_DIRS:-} && -x $system_thunar ]]; then
    plugin_dir=$(dirname "$(readlink -f "$system_thunar")")/../lib/thunarx-3
    if [[ -d $plugin_dir ]]; then
      export THUNARX_DIRS=$plugin_dir
    fi
  fi
elif [[ -x $system_thunar ]]; then
  thunar_bin=$system_thunar
else
  thunar_bin=$(command -v thunar)
fi

exec "$thunar_bin" "$@"
