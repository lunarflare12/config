#!/usr/bin/env bash
# Finder-style Thunar custom actions.
set -euo pipefail

usage() {
  echo "finder-action.sh new-window|info|duplicate|alias|preview|compress|share|color [--] PATHS..." >&2
  exit 2
}

[[ $# -ge 1 ]] || usage
cmd=$1
shift
[[ "${1:-}" == "--" ]] && shift
[[ $# -ge 1 ]] || usage

zenity_bin() { command -v zenity 2>/dev/null || true; }

finder_bin() {
  local s=${HOME}/.config/scripts/finder.sh
  if [[ -x $s ]]; then
    printf '%s' "$s"
    return
  fi
  printf '%s' /run/current-system/sw/bin/thunar
}

info_one() {
  local p=$1
  local t mime size mtime
  if [[ -d $p ]]; then
    t=Folder
  else
    t=File
  fi
  size=$(du -sh -- "$p" 2>/dev/null | awk '{print $1}')
  mime=$(file --mime-type -b -- "$p" 2>/dev/null || echo unknown)
  mtime=$(date -d "@$(stat -c %Y -- "$p")" '+%d %b %Y at %H:%M' 2>/dev/null || stat -c %y -- "$p")
  printf '%s\n\nKind: %s\nSize: %s\nType: %s\nModified: %s\nWhere: %s\n' \
    "$(basename -- "$p")" "$t" "${size:-—}" "$mime" "$mtime" "$(dirname -- "$p")"
}

preview_one() {
  local blob="" p qs
  qs=$(command -v qs 2>/dev/null || true)
  [[ -n $qs ]] || qs=/etc/profiles/per-user/${USER}/bin/qs
  for p in "$@"; do
    blob+="${p}"$'\n'
  done
  exec "$qs" ipc call preview toggle "$blob"
}

color_one() {
  local p=$1 z pick icon
  [[ -d $p ]] || return 0
  z=$(zenity_bin)
  [[ -n $z ]] || return 1
  pick=$(
    "$z" --list --radiolist --title="Customise Folder" --text="$(basename -- "$p")" \
      --hide-header --column=sel --column=Colour --width=280 --height=360 \
      TRUE Default \
      FALSE Red \
      FALSE Orange \
      FALSE Yellow \
      FALSE Green \
      FALSE Blue \
      FALSE Purple \
      FALSE Grey \
      FALSE Black \
      || true
  )
  [[ -n $pick ]] || return 0
  case $pick in
    Default) gio set -t unset -- "$p" metadata::custom-icon-name 2>/dev/null || true ;;
    Red) icon=folder-red ;;
    Orange) icon=folder-orange ;;
    Yellow) icon=folder-yellow ;;
    Green) icon=folder-green ;;
    Blue) icon=folder-blue ;;
    Purple) icon=folder-purple ;;
    Grey) icon=folder-grey ;;
    Black) icon=folder-black ;;
    *) return 0 ;;
  esac
  if [[ -n ${icon:-} ]]; then
    gio set -t string -- "$p" metadata::custom-icon-name "$icon"
  fi
  touch -- "$p"
}

duplicate_one() {
  local src=$1 dir name dest n=2
  dir=$(dirname -- "$src")
  name=$(basename -- "$src")
  dest="$dir/$name copy"
  while [[ -e $dest ]]; do
    dest="$dir/$name copy $n"
    n=$((n + 1))
  done
  cp -a -- "$src" "$dest"
}

alias_one() {
  local src=$1 dir name dest n=2
  dir=$(dirname -- "$src")
  name=$(basename -- "$src")
  dest="$dir/$name alias"
  while [[ -e $dest ]]; do
    dest="$dir/$name alias $n"
    n=$((n + 1))
  done
  ln -s -- "$src" "$dest"
}

share_files() {
  local uris="" p
  for p in "$@"; do
    uris+=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$p")
    uris+=$'\n'
  done
  if command -v wl-copy >/dev/null; then
    printf '%s' "$uris" | wl-copy --type text/uri-list
  fi
  if command -v notify-send >/dev/null; then
    notify-send Finder "Copied $(basename -- "$1") for sharing"
  fi
}

case $cmd in
  new-window)
    exec "$(finder_bin)" "$1"
    ;;
  info)
    text=""
    for p in "$@"; do
      text+=$(info_one "$p")
      text+=$'\n\n'
    done
    z=$(zenity_bin)
    if [[ -n $z ]]; then
      exec "$z" --info --title="Info" --width=420 --text="$text"
    fi
    printf '%s' "$text"
    ;;
  duplicate)
    for p in "$@"; do duplicate_one "$p"; done
    ;;
  alias)
    for p in "$@"; do alias_one "$p"; done
    ;;
  preview)
    preview_one "$@"
    ;;
  compress)
    exec file-roller --add "$@"
    ;;
  share)
    share_files "$@"
    ;;
  color)
    color_one "$1"
    ;;
  *)
    usage
    ;;
esac
