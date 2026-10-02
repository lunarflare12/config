# Shared helpers for Steam launch wrappers. Sourced, not executed.

# Hyprland owns XWayland (:0, rootless). Never spawn a second X server.
# Docker used to bind the socket file and leave a directory; then Hyprland
# cannot listen and games die. Only repair that path.
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
    systemctl --user stop aurora-xwayland.service >/dev/null 2>&1 || true
  fi
}

# Bind /steam/steamapps/shadercache → ~/.cache/steam-shadercache.
# If that source dir is deleted+recreated while mounted, the mount sticks
# to the old inode (findmnt shows //deleted) and Steam gets
# "Disk write failure" on every shader update — the game then exits in 1s.
game_fix_shadercache_bind() {
  local src="${HOME:-/home/dd}/.cache/steam-shadercache"
  local dst=/steam/steamapps/shadercache
  local src_info dst_info
  mkdir -p "$src"
  # Never replace $src itself (rm -rf + mkdir): that orphans the bind.
  if ! findmnt -T "$dst" >/dev/null 2>&1; then
    systemctl restart steam-steamapps-shadercache.mount >/dev/null 2>&1 || true
  fi
  src_info=$(findmnt -n -o SOURCE -T "$src" 2>/dev/null || true)
  dst_info=$(findmnt -n -o SOURCE -T "$dst" 2>/dev/null || true)
  case "$dst_info" in
    *'//deleted'*|"")
      echo "game-lib: shadercache bind stale ($dst_info), remounting" >&2
      systemctl restart steam-steamapps-shadercache.mount >/dev/null 2>&1 || true
      dst_info=$(findmnt -n -o SOURCE -T "$dst" 2>/dev/null || true)
      ;;
  esac
  # Host write works: bind is live for this process.
  if touch "$dst/.aurora-bind-check" 2>/dev/null; then
    rm -f "$dst/.aurora-bind-check"
  else
    echo "game-lib: shadercache bind not writable, remounting" >&2
    systemctl restart steam-steamapps-shadercache.mount >/dev/null 2>&1 || true
  fi
  # Container keeps a pre-remount mount table. Restart when the box
  # still cannot create files under $dst.
  if docker inspect -f '{{.State.Running}}' steam 2>/dev/null | grep -qx true; then
    if ! docker exec steam touch "$dst/.aurora-bind-check" 2>/dev/null; then
      echo "game-lib: steam container has stale shadercache mount, restarting" >&2
      docker restart steam >/dev/null 2>&1 || true
      local i
      for i in $(seq 1 40); do
        if docker exec steam pgrep -f '/\.local/share/Steam/ubuntu12_32/steam$' >/dev/null 2>&1; then
          break
        fi
        sleep 0.5
      done
    else
      docker exec steam rm -f "$dst/.aurora-bind-check" >/dev/null 2>&1 || true
    fi
  fi
}

# One container (`steam`) owns the library. Games are processes inside it.
# Drop the old per-game containers. Never stop the Steam client here.
game_ensure_steam() {
  local compose="${COMPOSE:-${HOME:-/home/dd}/containers/steam/compose.yml}"
  local i
  game_fix_shadercache_bind
  docker rm -f terraria albion >/dev/null 2>&1 || true
  docker compose -f "$compose" up -d --no-deps --no-build steam
  for i in $(seq 1 40); do
    if docker inspect -f '{{.State.Running}}' steam 2>/dev/null | grep -qx true; then
      return 0
    fi
    sleep 0.25
  done
  echo "game-lib: steam container did not start" >&2
  return 1
}

game_stop_other_boxes() {
  local keep=${1:-}
  docker rm -f terraria albion >/dev/null 2>&1 || true
  case "$keep" in
    terraria)
      pkill -x Albion-Online >/dev/null 2>&1 || true
      pkill -x AlbionOnline >/dev/null 2>&1 || true
      pkill -x AlienShooter.exe >/dev/null 2>&1 || true
      ;;
    albion)
      pkill -x Terraria.exe >/dev/null 2>&1 || true
      pkill -x Terraria.bin >/dev/null 2>&1 || true
      pkill -x AlienShooter.exe >/dev/null 2>&1 || true
      ;;
    alien-shooter)
      pkill -x Terraria.exe >/dev/null 2>&1 || true
      pkill -x Terraria.bin >/dev/null 2>&1 || true
      pkill -x Albion-Online >/dev/null 2>&1 || true
      pkill -x AlbionOnline >/dev/null 2>&1 || true
      ;;
  esac
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
  if [ -x "${BASH_SOURCE[0]%/*}/cap-fossilize.sh" ]; then
    "${BASH_SOURCE[0]%/*}/cap-fossilize.sh" >/dev/null 2>&1 || true
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

# nvidia-settings inside the box has no NV-CONTROL, and on this driver
# GPUPowerMizerMode=1 is accepted and then stays 0. The card then sits
# near 1700 MHz / 20W while a game is open, so the 200 Hz panel starves.
# Call this on the host session before the container starts.
# Clocks via run0 are slow (~4s); do not block launch on them.
game_gpu_perf() {
  DISPLAY="${DISPLAY:-:0}" \
    nvidia-settings -a "[gpu:0]/GPUPowerMizerMode=1" >/dev/null 2>&1 || true
  (
    timeout 2 run0 nvidia-smi -lgc 2700,3090 >/dev/null 2>&1 || true
    timeout 2 run0 nvidia-smi -lmc 10501,14001 >/dev/null 2>&1 || true
  ) &
}

game_gpu_idle() {
  (
    timeout 2 run0 nvidia-smi -rgc >/dev/null 2>&1 || true
  ) &
}

# argv --safe-mode stays after rice restore. Only the autogenerated
# recoverycfg means stretch/fullscreen must be skipped.
game_hypr_broken() {
  local xdg="${HOST_XDG_RUNTIME_DIR:-${XDG_RUNTIME_DIR:-/run/user/1000}}"
  local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  local cfg
  if [ -z "$sig" ] && [ -d "$xdg/hypr" ]; then
    sig=$(find "$xdg/hypr" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %f\n' 2>/dev/null | sort -nr | awk 'NR==1{print $2}')
  fi
  [ -n "$sig" ] || return 1
  cfg="$xdg/hypr/$sig/recoverycfg.lua"
  [ -f "$cfg" ] || return 1
  grep -q 'autogenerated = true' "$cfg" 2>/dev/null
}

# Drop compositor extras while a game box is up. Do not touch monitors.
# render_unfocused_fps must stay 15 — setting 1 stuck after game exit = slideshow.
game_compositor_game() {
  local on=${1:-1}
  local lua
  if [ "$on" = 1 ]; then
    kill -STOP "$(pgrep -f '/mpvpaper ' | head -1)" >/dev/null 2>&1 || true
    lua='hl.config({ misc = { render_unfocused_fps = 15 }, decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } }, general = { border_size = 0, gaps_in = 0, gaps_out = 0 } })'
  else
    kill -CONT "$(pgrep -f '/mpvpaper ' | head -1)" >/dev/null 2>&1 || true
    lua='hl.config({ misc = { render_unfocused_fps = 15 }, decoration = { rounding = 16, blur = { enabled = true }, shadow = { enabled = true } }, general = { border_size = 4, gaps_in = 6, gaps_out = 10 }, xwayland = { use_nearest_neighbor = false } })'
  fi
  if [ -n "${STEAM_CONTAINER:-}" ] || [ -f /.dockerenv ]; then
    game_host hyprctl eval "$lua" >/dev/null 2>&1 || true
  else
    hyprctl eval "$lua" >/dev/null 2>&1 || true
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

# Re-modeset only when a monitor actually drifted. hl.monitor on an
# already-correct HDMI is a full DRM modeset — that is what made the
# Philips change resolution every game launch.
game_outputs_ok() {
  game_host hyprctl monitors -j 2>/dev/null | awk '
    /"name": "HDMI-A-2"/ || /"name": "HDMI-A-1"/ { t="h" }
    /"name": "DP-4"/ || /"name": "DP-1"/ { t="d" }
    t=="h" && /"width": 1920/ { hw=1 }
    t=="h" && /"height": 1080/ { hh=1 }
    t=="h" && /"refreshRate": 60/ { hr=1 }
    t=="h" && /"x": 2560/ { hx=1 }
    t=="d" && /"width": 2560/ { dw=1 }
    t=="d" && /"height": 1080/ { dh=1 }
    t=="d" && /"refreshRate": 200/ { dr=1 }
    t=="d" && /"x": 0,/ { dx=1 }
    END { exit !(hw && hh && hr && hx && dw && dh && dr && dx) }
  '
}

game_pin_outputs() {
  game_outputs_ok && return 0
  # Prefer live connector names (NVIDIA can renumber DP-1→DP-4).
  local dp hdmi
  dp=$(game_host hyprctl monitors -j 2>/dev/null | awk '
    /"name": "DP-/ { n=$0; gsub(/.*"name": "|".*/, "", n); if (n ~ /^DP-/) print n }
  ' | head -1)
  hdmi=$(game_host hyprctl monitors -j 2>/dev/null | awk '
    /"name": "HDMI-/ { n=$0; gsub(/.*"name": "|".*/, "", n); if (n ~ /^HDMI-/) print n }
  ' | head -1)
  dp=${dp:-DP-4}
  hdmi=${hdmi:-HDMI-A-2}
  game_host hyprctl eval "
hl.monitor({ output = \"${dp}\", mode = \"2560x1080@200.00Hz\", position = \"0x0\", scale = 1, bitdepth = 8, disabled = false })
hl.monitor({ output = \"${hdmi}\", mode = \"1920x1080@60.00Hz\", position = \"2560x0\", scale = 1, bitdepth = 8, disabled = false })
" >/dev/null 2>&1 || true
}

game_xwayland_ultrawide() {
  game_pin_outputs
}

game_xwayland_restore() {
  game_pin_outputs
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
      else print "2560 1080 200 DP-4"
    }
  '
}

game_x_primary() {
  # RandR --primary on XWayland also hits the real HDMI CRTC. No-op.
  return 0
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
  # XWayland lists HDMI as output 0. Wine RandR then modesets the Philips.
  if grep -q 'UseXRandR' "$reg"; then
    sed -i 's/"UseXRandR"="[^"]*"/"UseXRandR"="N"/' "$reg"
  elif grep -q '\[Software\\\\Wine\\\\X11 Driver\]' "$reg"; then
    sed -i '/\[Software\\\\Wine\\\\X11 Driver\]/a "UseXRandR"="N"\n"UseXVidMode"="N"' "$reg"
  fi
  if grep -q 'UseXVidMode' "$reg"; then
    sed -i 's/"UseXVidMode"="[^"]*"/"UseXVidMode"="N"/' "$reg"
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
