#!/usr/bin/env bash
# Host side of container xdg-open / FileManager1.ShowItems:
# open Finder on the download and select the file (macOS Reveal in Finder).
set -euo pipefail
export PATH="/run/current-system/sw/bin:/etc/profiles/per-user/${USER:-dd}/bin:${PATH:-}"

HOME="${HOME:-/home/dd}"
export HOME
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} && -d ${XDG_RUNTIME_DIR}/hypr ]]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(find "${XDG_RUNTIME_DIR}/hypr" -maxdepth 1 -mindepth 1 -printf '%T@ %f\n' 2>/dev/null | sort -nr | awk 'NR==1 { print $2 }')
  export HYPRLAND_INSTANCE_SIGNATURE
fi
unset DISPLAY
finder="${HOME}/.config/scripts/finder.sh"
[[ -x "$finder" ]] || finder=thunar

roots=(
  chrome-dd
  chrome-az
  chrome-hika
  chrome-sciencesoft
  firefox
  zen
  telegram-1
  telegram-2
)

decode() {
  # Prefer python; fall back when systemd PATH has no python3.
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$1"
    return
  fi
  local s=$1 out="" hex c
  while [[ -n $s ]]; do
    case "$s" in
      %[[:xdigit:]][[:xdigit:]]*)
        hex=${s:1:2}
        printf -v c "\\x${hex}"
        out+=$c
        s=${s:3}
        ;;
      +*)
        out+=' '
        s=${s:1}
        ;;
      *)
        out+=${s:0:1}
        s=${s:1}
        ;;
    esac
  done
  printf '%s\n' "$out"
}

file_uri() {
  if command -v python3 >/dev/null 2>&1; then
    python3 -c 'import sys, urllib.parse; print("file://" + urllib.parse.quote(sys.argv[1], safe="/"))' "$1"
    return
  fi
  local path=$1 c hex out=file://
  local i n=${#path}
  for ((i = 0; i < n; i++)); do
    c=${path:i:1}
    case "$c" in
      [A-Za-z0-9/._~-]) out+=$c ;;
      *)
        printf -v hex '%%%02X' "'$c"
        out+=$hex
        ;;
    esac
  done
  printf '%s\n' "$out"
}

host_path() {
  local raw=$1
  local root=$2
  local name=$3
  raw=${raw#file://localhost}
  raw=${raw#file://}
  raw=$(decode "$raw")
  case "$raw" in
    /home/app/Downloads|/home/app/Downloads/*)
      # User Downloads, same idea as macOS: browsers write here, Finder sees it.
      printf '%s\n' "${HOME}/Downloads${raw#/home/app/Downloads}"
      ;;
    /home/telegram/Downloads|/home/telegram/Downloads/*)
      printf '%s\n' "${HOME}/Downloads/${name}${raw#/home/telegram/Downloads}"
      ;;
    /home/app|/*)
      printf '%s\n' "${root}${raw#/home/app}"
      ;;
    /home/telegram|/*)
      # Telegram volume home is not on the host; only Downloads is shared.
      printf '%s\n' "${HOME}/Downloads/${name}${raw#/home/telegram}"
      ;;
    "${HOME}"/*|/home/dd/*)
      printf '%s\n' "$raw"
      ;;
    *)
      printf '%s\n' "$raw"
      ;;
  esac
}

launch() {
  local path=$1
  if [[ -d $path ]]; then
    reveal "$path"
    return 0
  fi
  if [[ ! -e $path ]]; then
    # Still try the parent folder so "open" after a move is not a no-op.
    local dir
    dir=$(dirname -- "$path")
    [[ -d $dir ]] && reveal "$dir"
    return 0
  fi
  systemd-run --user --scope --collect --quiet \
    -E HOME="$HOME" \
    -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    -E HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
    -E DISPLAY="" \
    -- xdg-open "$path" >/dev/null 2>&1 || xdg-open "$path" >/dev/null 2>&1 &
}

# Prefer Thunar's select API, then freedesktop ShowItems. Never pass a file
# path to `thunar` directly — CLI opens it with the default handler.
reveal() {
  local path=$1
  local dir name uri dir_uri
  if [[ -d $path ]]; then
    systemd-run --user --scope --collect --quiet \
      -E HOME="$HOME" \
      -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
      -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
      -E HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
      -E DISPLAY="" \
      -- "$finder" "$path" >/dev/null 2>&1 || "$finder" "$path" >/dev/null 2>&1 &
    return 0
  fi

  dir=$(dirname -- "$path")
  name=$(basename -- "$path")
  [[ -d $dir ]] || dir="${HOME}/Downloads"
  uri=$(file_uri "$path")
  dir_uri=$(file_uri "$dir")

  if gdbus call --session \
    --dest org.xfce.Thunar \
    --object-path /org/xfce/FileManager \
    --method org.xfce.FileManager.DisplayFolderAndSelect \
    "$dir_uri" "$name" "" "" >/dev/null 2>&1; then
    return 0
  fi

  if gdbus call --session \
    --dest org.freedesktop.FileManager1 \
    --object-path /org/freedesktop/FileManager1 \
    --method org.freedesktop.FileManager1.ShowItems \
    "['$uri']" "" >/dev/null 2>&1; then
    return 0
  fi

  # Cold start: open the folder, then select once Thunar claims the bus.
  systemd-run --user --scope --collect --quiet \
    -E HOME="$HOME" \
    -E XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    -E WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
    -E HYPRLAND_INSTANCE_SIGNATURE="${HYPRLAND_INSTANCE_SIGNATURE:-}" \
    -E DISPLAY="" \
    -- "$finder" "$dir" >/dev/null 2>&1 || "$finder" "$dir" >/dev/null 2>&1 &

  local i
  for i in $(seq 1 30); do
    sleep 0.1
    if gdbus call --session \
      --dest org.xfce.Thunar \
      --object-path /org/xfce/FileManager \
      --method org.xfce.FileManager.DisplayFolderAndSelect \
      "$dir_uri" "$name" "" "" >/dev/null 2>&1; then
      return 0
    fi
    if gdbus call --session \
      --dest org.freedesktop.FileManager1 \
      --object-path /org/freedesktop/FileManager1 \
      --method org.freedesktop.FileManager1.ShowItems \
      "['$uri']" "" >/dev/null 2>&1; then
      return 0
    fi
  done
  return 0
}

# Pick the newest non-empty request across containers. Scanning roots in
# order used to open a stale chrome/firefox ipc file instead of Telegram's.
best_file=""
best_mtime=0
best_name=""
best_kind=""
for name in "${roots[@]}"; do
  base="${HOME}/programs/${name}/ipc"
  for kind in launch open; do
    file="${base}/${kind}.path"
    [[ -s $file ]] || continue
    mtime=$(stat -c '%Y' "$file" 2>/dev/null || echo 0)
    if [[ -z $best_file || $mtime -gt $best_mtime ]]; then
      best_file=$file
      best_mtime=$mtime
      best_name=$name
      best_kind=$kind
    fi
  done
done

[[ -n $best_file ]] || exit 0

raw="$(cat "$best_file")"
rm -f "$best_file"
# Drop empty leftovers from other roots so the next PathChanged is clean.
for name in "${roots[@]}"; do
  for kind in launch open; do
    f="${HOME}/programs/${name}/ipc/${kind}.path"
    [[ -f $f && ! -s $f ]] && rm -f "$f"
  done
done

raw=${raw//$'\r'/}
raw=${raw%%$'\n'}
[[ -n $raw ]] || exit 0

target="$(host_path "$raw" "${HOME}/programs/${best_name}" "$best_name")"
action=$best_kind
[[ -n $target && -n $action ]] || exit 0

stamp="${XDG_RUNTIME_DIR}/container-open.last"
now=$(date +%s)
# NUL-safe stamp: paths contain spaces ("Telegram Desktop/...").
printf '%s\0%s\0%s\n' "$now" "$action" "$target" >"$stamp"

# Refuse to open a path that is not actually on the host share — better
# nothing than a sibling file from a mangled argv.
if [[ $action == launch && ! -e $target ]]; then
  printf 'container-open: missing %s (raw=%s)\n' "$target" "$raw" >&2
  dir=$(dirname -- "$target")
  [[ -d $dir ]] && reveal "$dir"
  exit 0
fi

if [[ $action == launch ]]; then
  launch "$target"
else
  reveal "$target"
fi
exit 0
