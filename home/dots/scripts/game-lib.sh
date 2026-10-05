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
  if docker inspect -f '{{.State.Running}}' steam 2>/dev/null | grep -qx true; then
    docker exec steam rm -f "$dst/.aurora-bind-check" >/dev/null 2>&1 || true
  fi
  # Never docker restart steam here. A recreate requeues the 8GB shader depot.
}

# One container (`steam`) owns the library. Games are processes inside it.
# Drop the old per-game containers. Never stop the Steam client here.
game_ensure_steam() {
  local compose="${COMPOSE:-${HOME:-/home/dd}/containers/steam/compose.yml}"
  local i
  game_fix_shadercache_bind
  docker rm -f terraria albion >/dev/null 2>&1 || true
  if docker inspect -f '{{.State.Running}}' steam 2>/dev/null | grep -qx true; then
    return 0
  fi
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
  local flag="${HOME:-/home/dd}/.local/state/aurora-game"
  if [ "$on" = 1 ]; then
    mkdir -p "${HOME:-/home/dd}/.local/state"
    : >"$flag"
    kill -STOP "$(pgrep -f '/mpvpaper ' | head -1)" >/dev/null 2>&1 || true
    pkill -STOP -f 'awww-daemon' >/dev/null 2>&1 || true
    pkill -STOP -x cava >/dev/null 2>&1 || true
    pkill -STOP -x quickshell >/dev/null 2>&1 || true
    pkill -STOP -f '/aurora fossilize loop' >/dev/null 2>&1 || true
    pkill -f 'fossilize_replay' >/dev/null 2>&1 || true
    lua='hl.config({ animations = { enabled = false }, misc = { render_unfocused_fps = 15, vrr = 0 }, decoration = { rounding = 0, blur = { enabled = false }, shadow = { enabled = false } }, general = { border_size = 0, gaps_in = 0, gaps_out = 0 }, render = { expand_undersized_textures = true, new_render_scheduling = false }, xwayland = { force_zero_scaling = true, use_nearest_neighbor = false }, debug = { vfr = false } })'
  else
    rm -f "$flag"
    kill -CONT "$(pgrep -f '/mpvpaper ' | head -1)" >/dev/null 2>&1 || true
    pkill -CONT -f 'awww-daemon' >/dev/null 2>&1 || true
    pkill -CONT -x cava >/dev/null 2>&1 || true
    pkill -CONT -x quickshell >/dev/null 2>&1 || true
    pkill -CONT -f '/aurora fossilize loop' >/dev/null 2>&1 || true
    lua='hl.config({ animations = { enabled = true }, misc = { render_unfocused_fps = 15 }, decoration = { rounding = 16, blur = { enabled = true }, shadow = { enabled = true } }, general = { border_size = 4, gaps_in = 6, gaps_out = 10 }, xwayland = { use_nearest_neighbor = false } })'
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
  # set -e must not take the launcher down if hyprctl cannot be reached.
  dp=$(game_host hyprctl monitors -j 2>/dev/null | awk '
    /"name": "DP-/ { n=$0; gsub(/.*"name": "|".*/, "", n); if (n ~ /^DP-/) print n }
  ' | head -1) || true
  hdmi=$(game_host hyprctl monitors -j 2>/dev/null | awk '
    /"name": "HDMI-/ { n=$0; gsub(/.*"name": "|".*/, "", n); if (n ~ /^HDMI-/) print n }
  ' | head -1) || true
  dp=${dp:-DP-4}
  hdmi=${hdmi:-HDMI-A-2}
  game_host hyprctl eval "
hl.monitor({ output = \"${dp}\", mode = \"2560x1080@200.00Hz\", position = \"0x0\", scale = 1, bitdepth = 8, disabled = false })
hl.monitor({ output = \"${hdmi}\", mode = \"1920x1080@60.00Hz\", position = \"2560x0\", scale = 1, bitdepth = 8, disabled = false })
" >/dev/null 2>&1 || true
}

# Overwatch enumerates one display and takes the X11 primary. Without this
# it lands on the 60 Hz HDMI, renders 1920x1080 and gets stretched to fit.
game_xwayland_primary() {
  local want=${1:-}
  local xr
  if [ -z "$want" ]; then
    want=$(game_monitor | awk '{print $4}')
  fi
  [ -n "$want" ] || return 0
  if [ -n "${STEAM_CONTAINER:-}" ] || [ -f /.dockerenv ]; then
    game_host env DISPLAY="${DISPLAY:-:0}" xrandr --output "$want" --primary >/dev/null 2>&1 || true
    return 0
  fi
  xr=$(command -v xrandr 2>/dev/null) || return 0
  DISPLAY="${DISPLAY:-:0}" "$xr" --output "$want" --primary >/dev/null 2>&1 || true
}

# X11 x-offset of one output as XWayland currently reports it.
game_xwayland_xpos() {
  game_host env DISPLAY="${DISPLAY:-:0}" xrandr --listmonitors 2>/dev/null | awk -v w="$1" '
    $NF == w {
      g = $(NF - 1)
      sub(/^[0-9]+\/[0-9]+x[0-9]+\/[0-9]+\+/, "", g)
      sub(/\+.*/, "", g)
      print g
      exit
    }
  '
}

# XWayland packs outputs in wl_output creation order, not by the Hyprland
# layout, so the HDMI takes X11 +0+0 and the ultrawide sits at +1920+0. Wine
# still reports its display at 0,0, so every click lands 1920 px off and the
# game also picks the 60 Hz panel. Destroying and recreating the other
# outputs appends them last, which leaves the ultrawide at +0+0.
game_xwayland_align() {
  local want=${1:-}
  [ -n "$want" ] || want=$(game_monitor | awk '{print $4}')
  [ -n "$want" ] || return 0
  [ "$(game_xwayland_xpos "$want")" = "0" ] && return 0

  local specs name mode pos scale
  specs=$(game_host hyprctl monitors 2>/dev/null | awk -v skip="$want" '
    /^Monitor /    { if (n != "" && n != skip && m != "") print n "|" m "|" p "|" s; n = $2; m = ""; p = ""; s = "1" }
    $1 ~ /^[0-9]+x[0-9]+@/ { m = $1; p = $3 }
    $1 == "scale:" { s = $2 }
    END           { if (n != "" && n != skip && m != "") print n "|" m "|" p "|" s }
  ')
  [ -n "$specs" ] || return 0

  while IFS='|' read -r name mode pos scale; do
    [ -n "$name" ] || continue
    game_host hyprctl eval "hl.monitor({ output = \"${name}\", disabled = true })" >/dev/null 2>&1 || true
  done <<<"$specs"
  sleep 2
  while IFS='|' read -r name mode pos scale; do
    [ -n "$name" ] || continue
    game_host hyprctl eval "hl.monitor({ output = \"${name}\", mode = \"${mode}Hz\", position = \"${pos}\", scale = ${scale:-1}, bitdepth = 8, disabled = false })" >/dev/null 2>&1 || true
  done <<<"$specs"
  sleep 3
}

game_xwayland_ultrawide() {
  game_pin_outputs
  game_xwayland_align
  game_xwayland_primary
}

game_xwayland_restore() {
  game_pin_outputs
}

# Host binaries (hyprctl/qs) cannot see Steam's libstdc++ / libcurl.
# Inside steam-box XDG_RUNTIME_DIR is /tmp/xdg — point hyprctl at the real session.
# Hyprland leaves its runtime directory behind when it restarts, and the dead
# instance keeps a .socket.sock that no longer accepts connections. Picking
# the alphabetically first one made every hyprctl in the box exit 4, and with
# set -e that killed the whole launcher. Probe newest-first instead; the
# signature is "<hash>_<unixtime>_<random>", so field 2 orders them.
game_hypr_sig() {
  local xdg="${HOST_XDG_RUNTIME_DIR:-/run/user/1000}"
  if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
    return 0
  fi
  if [ -n "${AURORA_HYPR_SIG:-}" ]; then
    printf '%s\n' "$AURORA_HYPR_SIG"
    return 0
  fi
  [ -d "$xdg/hypr" ] || return 0
  local cand
  for cand in $(ls -1 "$xdg/hypr" 2>/dev/null | awk -F_ '{ print $2 "\t" $0 }' | sort -k1,1nr | cut -f2); do
    if env -u LD_PRELOAD -u LD_LIBRARY_PATH -u STEAM_RUNTIME_LIBRARY_PATH \
        PATH="/run/current-system/sw/bin:/etc/profiles/per-user/dd/bin" \
        XDG_RUNTIME_DIR="$xdg" HYPRLAND_INSTANCE_SIGNATURE="$cand" \
        hyprctl version >/dev/null 2>&1; then
      AURORA_HYPR_SIG="$cand"
      export AURORA_HYPR_SIG
      printf '%s\n' "$cand"
      return 0
    fi
  done
  return 0
}

game_host() {
  local xdg="${HOST_XDG_RUNTIME_DIR:-/run/user/1000}"
  local sig
  sig=$(game_hypr_sig) || sig=""
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

# Wine virtual desktop = the only display DXGI/OW will list. 1920×1080
# keeps 16:9; Hyprland then stretches that window across 2560×1080@200.
game_wine_desktop_off() {
  local reg=$1
  [ -f "$reg" ] || return 0
  sed -i '/\[Software\\\\Wine\\\\Explorer\]/,/^\[/{ /"Desktop"=/d; }' "$reg" || true
}

game_wine_desktop() {
  local reg=$1
  local size=${2:-1920x1080}
  local name=${3:-ow1920}
  [ -f "$reg" ] || return 0
  if grep -q '\[Software\\\\Wine\\\\Explorer\]' "$reg"; then
    if grep -q '"Desktop"=' "$reg"; then
      sed -i "s/\"Desktop\"=\"[^\"]*\"/\"Desktop\"=\"${name}\"/" "$reg"
    else
      sed -i "/\[Software\\\\Wine\\\\Explorer\]/a \"Desktop\"=\"${name}\"" "$reg"
    fi
  else
    printf '\n[Software\\\\Wine\\\\Explorer]\n"Desktop"="%s"\n' "$name" >>"$reg"
  fi
  if grep -q '\[Software\\\\Wine\\\\Explorer\\\\Desktops\]' "$reg"; then
    if grep -q "\"${name}\"=" "$reg"; then
      sed -i "s/\"${name}\"=\"[^\"]*\"/\"${name}\"=\"${size}\"/" "$reg"
    else
      sed -i "/\[Software\\\\Wine\\\\Explorer\\\\Desktops\]/a \"${name}\"=\"${size}\"" "$reg"
    fi
  else
    printf '\n[Software\\\\Wine\\\\Explorer\\\\Desktops]\n"%s"="%s"\n' "$name" "$size" >>"$reg"
  fi
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
  # This used to be "N" because XWayland listed HDMI as output 0 and wine
  # RandR modeset the Philips. game_xwayland_align now puts the ultrawide
  # first, so that reason is gone — and with RandR off wine cannot read the
  # real mode at all. It synthesises a 60 Hz list, the game believes the
  # panel is 60 Hz and caps there no matter what FrameRateCap says.
  # XVidMode stays off: it is the legacy path and it does modeset.
  if grep -q 'UseXRandR' "$reg"; then
    sed -i 's/"UseXRandR"="[^"]*"/"UseXRandR"="Y"/' "$reg"
  elif grep -q '\[Software\\\\Wine\\\\X11 Driver\]' "$reg"; then
    sed -i '/\[Software\\\\Wine\\\\X11 Driver\]/a "UseXRandR"="Y"\n"UseXVidMode"="N"' "$reg"
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

game_place_overwatch() {
  # Repeating a move+fullscreen while Proton mapped a second surface put
  # the game on two workspaces. The compositor rule fullscreens one window.
  return 0
}

# Biggest on-disk copy of one Overwatch pipeline depot (download dir or final).
game_ow_hash_bytes() {
  local hash=$1 root
  root=/steam/steamapps/shadercache/2357570
  [ -d "$root" ] || root="${HOME:-/home/dd}/.local/share/Steam/steamapps/shadercache/2357570"
  find "$root" -path "*${hash}*" -name steam_pipeline_cache.foz -printf '%s\n' 2>/dev/null \
    | LC_ALL=C awk 'BEGIN{m=0} {if ($1+0>m) m=$1+0} END{printf "%.0f\n", m}'
}

game_fossil_alive() {
  local d comm
  for d in /proc/[0-9]*; do
    comm=$(cat "$d/comm" 2>/dev/null) || continue
    case "$comm" in
      fossilize_replay|fossilize-replay) return 0 ;;
    esac
  done
  return 1
}

# Steam applaunch used to sit on the 8GB shader depot even when 11G FOZ
# is already on disk. If either bucket is a real cache, play now.
game_wait_ow_shaders() {
  local a b
  a=$(game_ow_hash_bytes 904f69d2b1b44b65)
  b=$(game_ow_hash_bytes 2e6c105801134e9c)
  echo "game-lib: shader cache on disk a=$a b=$b (not waiting)" >&2
  return 0
}

# Steam shader update (~8.7G) greys Play and rewrites FOZ that already exists.
# Clear the queued depot counters. Do not restart Steam.
game_skip_ow_shader_update() {
  local acf cfg
  acf=/steam/steamapps/appmanifest_2357570.acf
  [ -f "$acf" ] || acf="${HOME:-/home/dd}/.local/share/Steam/steamapps/appmanifest_2357570.acf"
  if [ -f "$acf" ]; then
    sed -i \
      -e 's/"BytesToDownload"[[:space:]]*"[0-9]*"/"BytesToDownload"\t\t"0"/' \
      -e 's/"BytesDownloaded"[[:space:]]*"[0-9]*"/"BytesDownloaded"\t\t"0"/' \
      -e 's/"BytesToStage"[[:space:]]*"[0-9]*"/"BytesToStage"\t\t"0"/' \
      -e 's/"BytesStaged"[[:space:]]*"[0-9]*"/"BytesStaged"\t\t"0"/' \
      "$acf" || true
  fi
  cfg="${HOME:-/home/dd}/.local/share/Steam/config/config.vdf"
  if [ -f "$cfg" ]; then
    sed -i 's/"EnableShaderBackgroundProcessing"[[:space:]]*"1"/"EnableShaderBackgroundProcessing"\t\t"0"/' "$cfg" || true
  fi
  find /steam/steamapps/shadercache/2357570/downloads \
    "${HOME:-/home/dd}/.cache/steam-shadercache/2357570/downloads" \
    -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
  rm -f /steam/steamapps/shadercache/2357570/state_2357570_2357570.patch \
    "${HOME:-/home/dd}/.cache/steam-shadercache/2357570/state_2357570_2357570.patch" \
    2>/dev/null || true
}
