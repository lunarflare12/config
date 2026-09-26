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
)

decode() {
  python3 -c 'import sys, urllib.parse; print(urllib.parse.unquote(sys.argv[1]))' "$1"
}

file_uri() {
  python3 -c 'import sys, urllib.parse; print("file://" + urllib.parse.quote(sys.argv[1], safe="/"))' "$1"
}

host_path() {
  local raw=$1
  local root=$2
  raw=${raw#file://localhost}
  raw=${raw#file://}
  raw=$(decode "$raw")
  case "$raw" in
    /home/app/Downloads|/home/app/Downloads/*)
      # User Downloads, same idea as macOS: browsers write here, Finder sees it.
      printf '%s\n' "${HOME}/Downloads${raw#/home/app/Downloads}"
      ;;
    /home/app|/*)
      printf '%s\n' "${root}${raw#/home/app}"
      ;;
    "${HOME}"/*|/home/dd/*)
      printf '%s\n' "$raw"
      ;;
    *)
      printf '%s\n' "$raw"
      ;;
  esac
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

target=""
for name in "${roots[@]}"; do
  file="${HOME}/programs/${name}/ipc/open.path"
  [[ -s "$file" ]] || continue
  raw="$(cat "$file")"
  rm -f "$file"
  [[ -n "$raw" ]] || continue
  target="$(host_path "$raw" "${HOME}/programs/${name}")"
  break
done

[[ -n "$target" ]] || exit 0

stamp="${XDG_RUNTIME_DIR}/container-open.last"
now=$(date +%s)
if [[ -f $stamp ]]; then
  last_t=""
  last_target=""
  read -r last_t last_target <"$stamp" || true
  # Same file within 2s is a double-fire from Chrome; different files must pass.
  if [[ $last_target == "$target" && -n $last_t && $((now - last_t)) -lt 2 ]]; then
    exit 0
  fi
fi
printf '%s %s\n' "$now" "$target" >"$stamp"

reveal "$target"
exit 0
