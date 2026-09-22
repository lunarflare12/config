#!/usr/bin/env bash
# Apply an XCursor theme by catalogue id or theme name.
set -u

id="${1:?Usage: set-cursor.sh <cursor-id> [size] [theme]}"
size="${2:-${AURORA_CURSOR_SIZE:-24}}"
theme="${3:-$id}"
home="${HOME}"
state_dir="${XDG_CACHE_HOME:-$home/.cache}/aurora"
catalogue="${home}/config/home/dots/aurora-qs/assets/cursors/catalogue.json"
if [[ ! -f "$catalogue" ]]; then
  catalogue="${home}/.config/quickshell/assets/cursors/catalogue.json"
fi

bin() {
  local name="$1"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  if [[ -x "/run/current-system/sw/bin/$name" ]]; then
    printf '%s\n' "/run/current-system/sw/bin/$name"
    return 0
  fi
  return 1
}

HYPRCTL="$(bin hyprctl || true)"
PYTHON3="$(bin python3 || true)"
GSETTINGS="$(bin gsettings || true)"

mkdir -p "$state_dir"

if [[ -f "$catalogue" && -n "${PYTHON3:-}" ]]; then
  resolved="$("$PYTHON3" - "$catalogue" "$id" "$theme" <<'PY'
import json, sys
path, needle, fallback = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    data = json.load(open(path, encoding="utf-8"))
except Exception:
    print(fallback)
    raise SystemExit(0)
items = data if isinstance(data, list) else data.get("cursors", [])
for item in items:
    if item.get("id") == needle or item.get("theme") == needle or item.get("name") == needle:
        print(item.get("theme") or item.get("id") or fallback)
        raise SystemExit(0)
print(fallback)
PY
)"
  if [[ -n "${resolved:-}" ]]; then
    theme="$resolved"
  fi
fi

theme_dir=""
find_theme() {
  local name="$1"
  local cand
  for cand in \
    "$home/.local/share/icons/$name" \
    "$home/.icons/$name" \
    "$home/config/home/dots/cursors/themes/$name"
  do
    if [[ -e "$cand/cursors/left_ptr" || -e "$cand/cursors/default" ]]; then
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 1
}

theme_dir="$(find_theme "$theme" || true)"
if [[ -z "$theme_dir" && "$theme" != "$id" ]]; then
  theme_dir="$(find_theme "$id" || true)"
fi
if [[ -z "$theme_dir" ]]; then
  for cand in "$home/.icons"/* "$home/.local/share/icons"/* "$home/config/home/dots/cursors/themes"/*; do
    [[ -e "$cand" ]] || continue
    base="$(basename "$cand")"
    if [[ "${base,,}" == "${theme,,}" || "${base,,}" == "${id,,}" ]]; then
      if [[ -e "$cand/cursors/left_ptr" || -e "$cand/cursors/default" ]]; then
        theme_dir="$cand"
        theme="$base"
        break
      fi
    fi
  done
fi

printf '%s\n' "$id" > "$state_dir/current-cursor"
printf '%s\n' "$theme" > "$state_dir/current-cursor-theme"
printf '%s\n' "$size" > "$state_dir/current-cursor-size"
chmod u+w "$state_dir/current-cursor" "$state_dir/current-cursor-theme" "$state_dir/current-cursor-size" 2>/dev/null || true

if [[ -z "$theme_dir" ]]; then
  printf 'set-cursor: theme %s is not installed\n' "$theme" >&2
  exit 1
fi

default_dir="$home/.icons/default"
mkdir -p "$default_dir"
default_index="$default_dir/index.theme"
if [[ -L "$default_index" ]]; then
  rm -f "$default_index"
fi
printf '%s\n' "[Icon Theme]" "Name=Default" "Comment=Default Cursor Theme" "Inherits=$theme" > "$default_index"

rewrite_gtk() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  if [[ -L "$file" ]]; then
    local tmp
    tmp="$(mktemp)"
    cat "$file" > "$tmp"
    mv "$tmp" "$file"
  fi
  [[ -w "$file" ]] || return 0
  if grep -q '^gtk-cursor-theme-name=' "$file"; then
    sed -i "s/^gtk-cursor-theme-name=.*/gtk-cursor-theme-name=$theme/" "$file"
  else
    printf '%s\n' "gtk-cursor-theme-name=$theme" >> "$file"
  fi
  if grep -q '^gtk-cursor-theme-size=' "$file"; then
    sed -i "s/^gtk-cursor-theme-size=.*/gtk-cursor-theme-size=$size/" "$file"
  else
    printf '%s\n' "gtk-cursor-theme-size=$size" >> "$file"
  fi
}

rewrite_gtk "$home/.config/gtk-3.0/settings.ini"
rewrite_gtk "$home/.config/gtk-4.0/settings.ini"

if [[ -n "${GSETTINGS:-}" ]]; then
  "$GSETTINGS" set org.gnome.desktop.interface cursor-theme "$theme" >/dev/null 2>&1 || true
  "$GSETTINGS" set org.gnome.desktop.interface cursor-size "$size" >/dev/null 2>&1 || true
fi

hypr_size="$size"
if [[ -n "${PYTHON3:-}" ]]; then
  left_ptr=""
  for cand in "$theme_dir/cursors/left_ptr" "$theme_dir/cursors/default"; do
    if [[ -e "$cand" ]]; then
      left_ptr="$cand"
      break
    fi
  done
  if [[ -n "$left_ptr" ]]; then
    nearest="$("$PYTHON3" - "$left_ptr" "$size" <<'PY'
import struct, sys
path, want = sys.argv[1], int(sys.argv[2])
data = open(path, "rb").read()
if data[:4] != b"Xcur":
    print(want)
    raise SystemExit(0)
_nmagic, _hs, _ver, ntoc = struct.unpack_from("<4sIII", data, 0)
sizes = set()
off = 16
for _ in range(ntoc):
    ctype, subtype, pos = struct.unpack_from("<III", data, off)
    off += 12
    if ctype == 0xFFFD0002:
        sizes.add(subtype if subtype else struct.unpack_from("<I", data, pos + 8)[0])
if not sizes:
    print(want)
    raise SystemExit(0)
print(min(sizes, key=lambda s: (abs(s - want), s)))
PY
)"
    if [[ -n "${nearest:-}" ]]; then
      hypr_size="$nearest"
    fi
  fi
fi

if [[ -n "${HYPRCTL:-}" ]]; then
  "$HYPRCTL" eval "hl.env('XCURSOR_THEME', '${theme}')" >/dev/null 2>&1 || true
  "$HYPRCTL" eval "hl.env('XCURSOR_SIZE', '${hypr_size}')" >/dev/null 2>&1 || true
  "$HYPRCTL" eval "hl.env('HYPRCURSOR_THEME', '${theme}')" >/dev/null 2>&1 || true
  "$HYPRCTL" eval "hl.env('HYPRCURSOR_SIZE', '${hypr_size}')" >/dev/null 2>&1 || true
  "$HYPRCTL" eval "hl.config({ cursor = { enable_hyprcursor = true, no_hardware_cursors = true, use_cpu_buffer = false, hide_on_key_press = false, default_monitor = 'DP-1' } })" >/dev/null 2>&1 || true
  "$HYPRCTL" setcursor "$theme" "$hypr_size" >/dev/null 2>&1 || true
  "$HYPRCTL" setcursor "$theme" "$size" >/dev/null 2>&1 || true
  {
    printf '%s\n' "id=$id theme=$theme size=$size hypr_size=$hypr_size dir=$theme_dir"
  } >> "$state_dir/set-cursor.log"
fi

exit 0
