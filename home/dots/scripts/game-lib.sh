# Shared helpers for Steam launch wrappers. Sourced, not executed.

# Hyprland's own Xwayland stays dead if /tmp/.X11-unix/X0 was replaced by a
# directory (Docker used to bind the socket file). Games need a live socket.
game_ensure_xwayland() {
  if [ -S /tmp/.X11-unix/X0 ]; then
    return 0
  fi
  if [ -d /tmp/.X11-unix/X0 ]; then
    docker run --rm --user 0 --entrypoint /bin/rmdir \
      -v /tmp/.X11-unix:/tmp/.X11-unix steam-box:1 /tmp/.X11-unix/X0 >/dev/null 2>&1 || true
  fi
  rm -f /tmp/.X11-unix/X0 2>/dev/null || true
  if systemctl --user is-active aurora-xwayland.service >/dev/null 2>&1; then
    return 0
  fi
  systemd-run --user --unit=aurora-xwayland \
    -p Restart=on-failure \
    -p RestartSec=1 \
    -p Environment="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}" \
    -p Environment="XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/1000}" \
    Xwayland :0 -nolisten tcp -ac >/dev/null 2>&1 || true
}

# One Steam library lock. steam / overwatch / terraria / albion cannot run together.
game_stop_other_boxes() {
  local keep=${1:-}
  local name
  for name in steam overwatch terraria albion; do
    [ "$name" = "$keep" ] && continue
    docker stop "$name" >/dev/null 2>&1 || true
  done
  if [ -n "$keep" ]; then
    docker rm -f "$keep" >/dev/null 2>&1 || true
  fi
  if pgrep -f '/\.local/share/Steam/ubuntu12_32/steam' >/dev/null 2>&1; then
    pkill -f '/\.local/share/Steam/ubuntu12_32/steam' >/dev/null 2>&1 || true
    sleep 1
  fi
}

game_block_fossilize() {
  # Do not pkill fossilize_replay: Steam owns the Play-time compile.
  # Only pin launch options (albion.sh). Never wipe shader caches here.
  if [ -x "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" ]; then
    "${BASH_SOURCE[0]%/*}/protect-shader-caches.sh" >/dev/null 2>&1 || true
  fi
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
  # Steam client pins SDL to X11. Wrappers that want X11 set it again after this.
  unset SDL_VIDEODRIVER || true
}

# nvidia-settings inside the box has no NV-CONTROL — GPU stays in P3 / 25W.
# Call this on the host session before the container starts.
game_gpu_perf() {
  DISPLAY="${DISPLAY:-:0}" \
    nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" >/dev/null 2>&1 || true
}

# Drop compositor extras while a game box is up. Do not touch monitors.
game_compositor_game() {
  local on=${1:-1} cmd
  if [ "$on" = 1 ]; then
    cmd="keyword decoration:blur:enabled false; keyword decoration:shadow:enabled false; keyword misc:render_unfocused_fps 1; keyword render:expand_undersized_textures false"
  else
    cmd="keyword decoration:blur:enabled true; keyword decoration:shadow:enabled true; keyword misc:render_unfocused_fps 15"
  fi
  if [ -n "${STEAM_CONTAINER:-}" ] || [ -f /.dockerenv ]; then
    game_host hyprctl --batch "$cmd" >/dev/null 2>&1 || true
  else
    hyprctl --batch "$cmd" >/dev/null 2>&1 || true
  fi
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

# Never disable HDMI / never flip "game mode" monitor layout.
game_xwayland_ultrawide() {
  :
}

game_xwayland_restore() {
  game_host hyprctl eval '
hl.monitor({ output = "DP-1", mode = "2560x1080@200.00Hz", position = "0x0", scale = 1, bitdepth = 8, disabled = false })
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60.00Hz", position = "2560x0", scale = 1, bitdepth = 8, disabled = false })
' >/dev/null 2>&1 || true
  DISPLAY="${DISPLAY:-:0}" game_host xrandr \
    --output DP-1 --primary --mode 2560x1080 --pos 0x0 \
    --output HDMI-A-1 --mode 1920x1080 --pos 2560x0 >/dev/null 2>&1 || true
}

# Host binaries (hyprctl/qs) cannot see Steam's libstdc++ / libcurl.
# Inside steam-box XDG_RUNTIME_DIR is /tmp/xdg — point hyprctl at the real session.
game_host() {
  local xdg="${HOST_XDG_RUNTIME_DIR:-/run/user/1000}"
  local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  if [ -z "$sig" ] && [ -d "$xdg/hypr" ]; then
    sig=$(ls -1 "$xdg/hypr" 2>/dev/null | head -n1)
  fi
  env -u LD_PRELOAD -u LD_LIBRARY_PATH -u STEAM_RUNTIME_LIBRARY_PATH \
    PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin" \
    XDG_RUNTIME_DIR="$xdg" \
    HYPRLAND_INSTANCE_SIGNATURE="$sig" \
    "$@"
}

game_place_overwatch() {
  (
    local i
    # A few silent pins while Proton maps. Do not focus workspace 4 — that
    # yanked every desktop onto the game. Stop once the client is gone so
    # this loop cannot fight Alt+F4 / Steam stop.
    for i in $(seq 1 6); do
      sleep 0.4
      game_host hyprctl eval '
local w
for _, x in ipairs(hl.get_windows()) do
  local c = string.lower(tostring(x.initial_class or "") .. " " .. tostring(x.class or ""))
  if c:find("steam", 1, true) and not c:find("steam_app_", 1, true) then
    -- Steam library title is often "Overwatch 2"
  elseif c:find("steam_app_2357570", 1, true) or c:find("overwatch", 1, true) then
    w = x
    break
  end
end
if not w then
  return false
end
pcall(function()
  hl.dispatch(hl.dsp.window.move({ workspace = 4, window = w, silent = true }))
end)
pcall(function()
  hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, internal = 2, client = 0 }))
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
          # First hit wins; drop spaced/duplicate keys the game rewrites.
          if (!done) {
            emit()
            done = 1
          }
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
