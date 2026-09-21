# Shared helpers for Steam launch wrappers. Sourced, not executed.

game_block_fossilize() {
  # Do not pkill fossilize_replay: Steam owns the Play-time compile.
  # Only pin launch options (albion.sh).
  if [ -x "${BASH_SOURCE[0]%/*}/steam-lock-shaders.sh" ]; then
    "${BASH_SOURCE[0]%/*}/steam-lock-shaders.sh" >/dev/null 2>&1 || true
  fi
}

game_strip_overlay() {
  [ -n "${LD_PRELOAD:-}" ] || return 0
  local filtered="" p old_ifs=$IFS
  IFS=:
  for p in $LD_PRELOAD; do
    case "$p" in
      *gameoverlayrenderer*) ;;
      "") ;;
      *)
        if [ -z "$filtered" ]; then
          filtered=$p
        else
          filtered="$filtered:$p"
        fi
        ;;
    esac
  done
  IFS=$old_ifs
  export LD_PRELOAD="$filtered"
}

game_low_latency() {
  export __GL_SYNC_TO_VBLANK=0
  export vblank_mode=0
}

game_gamescope() {
  local wrapped=/run/wrappers/bin/gamescope
  local plain=/run/current-system/sw/bin/gamescope
  # Steam's FHS bwrap cannot inherit NixOS file caps. After the 13 Sep
  # wrapper rebuild that prints "failed to inherit capabilities" and
  # exits, the game dies in ~4s and Steam thinks it closed.
  if [ -z "${SteamAppId:-}${SteamGameId:-}${STEAM_COMPAT_CLIENT_INSTALL_PATH:-}" ] && [ -x "$wrapped" ]; then
    echo "$wrapped"
    return 0
  fi
  if [ -x "$plain" ]; then
    echo "$plain"
    return 0
  fi
  if command -v gamescope >/dev/null 2>&1; then
    command -v gamescope
    return 0
  fi
  return 1
}

# Host binaries (hyprctl/qs) cannot see Steam's libstdc++ / libcurl.
game_host() {
  env -u LD_PRELOAD -u LD_LIBRARY_PATH -u STEAM_RUNTIME_LIBRARY_PATH \
    PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin" \
    "$@"
}

game_place_overwatch() {
  (
    local i
    for i in $(seq 1 12); do
      sleep 0.5
      game_host hyprctl eval '
local w
for _, x in ipairs(hl.get_windows()) do
  local c = string.lower(tostring(x.initial_class or x.class or ""))
  local t = string.lower(tostring(x.title or ""))
  if c:find("steam_app_2357570", 1, true) or c:find("overwatch", 1, true) or t:find("overwatch", 1, true) then
    w = x
    break
  end
end
if w then
  pcall(function()
    hl.dispatch(hl.dsp.window.move({ workspace = 14, window = w }))
  end)
  pcall(function()
    hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, internal = 1, client = 0 }))
  end)
end
' >/dev/null 2>&1 || true
    done
  ) &
}

game_monitor() {
  game_host hyprctl monitors 2>/dev/null | awk '
    /^Monitor / { name = $2 }
    $1 ~ /^[0-9]+x[0-9]+@/ {
      split($1, r, /[x@]/)
      area = r[1] * r[2]
      if (area >= best) {
        best = area
        w = r[1]
        h = r[2]
        hz = r[3] + 0
        n = name
      }
    }
    END {
      if (n != "") printf "%s %s %d %s\n", w, h, hz, n
      else print "2560 1080 200 DP-1"
    }
  '
}

game_x_primary() {
  local width=$1 height=$2 output
  command -v xrandr >/dev/null 2>&1 || return 0
  output=$(xrandr --query 2>/dev/null | awk -v size="${width}x${height}" '
    / connected/ && $0 !~ /disconnected/ && index($0, size) { print $1; exit }
  ')
  [ -n "$output" ] || return 0
  xrandr --output "$output" --primary >/dev/null 2>&1 || true
}

# SDL2-compat monitor index for the ultrawide (DP-1 2560x1080@200).
game_display_index() {
  local width=$1 height=$2
  command -v xrandr >/dev/null 2>&1 || { echo 0; return 0; }
  xrandr --listmonitors 2>/dev/null | awk -v tw="$width" -v th="$height" '
    NR > 1 {
      idx = $1
      gsub(/:/, "", idx)
      split($3, a, /[\/x+]/)
      if (a[1] + 0 == tw && a[3] + 0 == th) { print idx; exit }
    }
    END { if (NR) {} }
  '
}

game_wine_warp() {
  local reg=$1
  local mode=${2:-disable}
  [ -f "$reg" ] || return 0
  if grep -q 'MouseWarpOverride' "$reg"; then
    sed -i "s/\"MouseWarpOverride\"=\"[^\"]*\"/\"MouseWarpOverride\"=\"${mode}\"/" "$reg"
  elif grep -q '\[Software\\\\Wine\\\\X11 Driver\]' "$reg"; then
    sed -i "/\[Software\\\\Wine\\\\X11 Driver\]/a \"MouseWarpOverride\"=\"${mode}\"\n\"GrabFullscreen\"=\"N\"" "$reg"
  else
    printf '\n[Software\\\\Wine\\\\X11 Driver]\n"MouseWarpOverride"="%s"\n"GrabFullscreen"="N"\n' "$mode" >>"$reg"
  fi
  if grep -q 'GrabFullscreen' "$reg"; then
    sed -i 's/"GrabFullscreen"="[^"]*"/"GrabFullscreen"="N"/' "$reg"
  fi
}

# game_ini_set FILE SECTION KEY VALUE
# VALUE is written as-is after "=" (include quotes if the game wants them).
game_ini_set() {
  local file=$1 section=$2 key=$3 val=$4
  local tmp
  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || printf '%s\n' "$section" >"$file"
  tmp=$(mktemp)
  awk -v sect="$section" -v key="$key" -v val="$val" '
    function emit() { print key "=" val }
    {
      line = $0
      sub(/\r$/, "", line)
      if (line ~ /^\[.*\]$/) {
        if (insec && !done) emit()
        insec = (line == sect)
        print line
        next
      }
      if (insec) {
        split(line, parts, "=")
        k = parts[1]
        gsub(/^[ \t]+|[ \t]+$/, "", k)
        if (k == key) {
          emit()
          done = 1
          next
        }
      }
      print line
    }
    END {
      if (!done) {
        if (!insec) print sect
        emit()
      }
    }
  ' "$file" >"$tmp" && mv "$tmp" "$file"
}
