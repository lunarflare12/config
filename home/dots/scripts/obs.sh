#!/usr/bin/env bash
# Click from launcher → OBS main WINDOW must open.
# Tray preload is only a warm cache; never leave the user tray-only after a click.
set -euo pipefail

export LD_LIBRARY_PATH="/run/opengl-driver/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
unset LIBVA_DRIVER_NAME LIBVA_DRIVERS_PATH

OBS="/run/current-system/sw/bin/obs"
HYPRCTL="$(command -v hyprctl || true)"
PIDFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/obs-tray.pid"
SNIFILE="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/obs-sni"
LOG="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/obs-launch.log"

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >>"$LOG" 2>/dev/null || true; }

ensure_hypr_env() {
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    [ -S "$XDG_RUNTIME_DIR/wayland-1" ] && export WAYLAND_DISPLAY=wayland-1
    [ -z "${WAYLAND_DISPLAY:-}" ] && [ -S "$XDG_RUNTIME_DIR/wayland-0" ] && export WAYLAND_DISPLAY=wayland-0
  fi
  if [ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    local d
    for d in "$XDG_RUNTIME_DIR"/hypr/*/; do
      [ -d "$d" ] || continue
      export HYPRLAND_INSTANCE_SIGNATURE="$(basename "$d")"
      break
    done
  fi
  if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
  fi
}

is_obs_pid() {
  local pid="$1" cmd
  [ -n "$pid" ] || return 1
  [ -r "/proc/$pid/cmdline" ] || return 1
  cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
  case "$cmd" in
    *'/.obs-wrapped'*|*'/bin/obs '*|*'/bin/obs'|*/obs\ --*|*/obs)
      return 0
      ;;
  esac
  return 1
}

obs_pid() {
  local p
  if [ -f "$PIDFILE" ]; then
    p="$(tr -d ' \n' <"$PIDFILE" 2>/dev/null || true)"
    if is_obs_pid "$p"; then
      printf '%s\n' "$p"
      return 0
    fi
    rm -f "$PIDFILE"
  fi
  for p in $(pgrep -x '.obs-wrapped' 2>/dev/null || true) \
           $(pgrep -x obs 2>/dev/null || true); do
    if is_obs_pid "$p"; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

obs_window_mapped() {
  [ -n "$HYPRCTL" ] || return 1
  "$HYPRCTL" repl \
    'for _,w in pairs(hl.get_windows()) do local c=(w.class or ""):lower(); if c:find("obsproject") then print("yes"); return end end' \
    2>/dev/null | grep -q yes
}

hypr_focus_obs() {
  local out
  [ -n "$HYPRCTL" ] || return 1
  out="$("$HYPRCTL" dispatch 'hl.dsp.focus({ window = "class:com.obsproject.Studio" })' 2>&1 || true)"
  case "$out" in
    *'window not found'*) return 1 ;;
    ok|ok$'\n'*|*'ok'*) return 0 ;;
  esac
  return 1
}

sni_activate() {
  python3 - "$SNIFILE" <<'PY'
import re, subprocess, sys
snifile = sys.argv[1]

def run(cmd, t=0.3):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=t)
    except Exception:
        return None

def activate(dest, path):
    for iface in ("org.kde.StatusNotifierItem", "org.freedesktop.StatusNotifierItem"):
        a = run(["busctl", "--user", "call", dest, path, iface, "Activate", "ii", "0", "0"], t=0.3)
        if a and a.returncode == 0:
            return True
    return False

# Try cache first.
try:
    raw = open(snifile).read().strip()
    if "/" in raw:
        dest, path = raw.split("/", 1)
        if activate(dest, "/" + path):
            sys.exit(0)
except Exception:
    pass

out = run(["busctl", "--user", "get-property",
           "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher",
           "org.kde.StatusNotifierWatcher", "RegisteredStatusNotifierItems"])
if not out or out.returncode != 0:
    sys.exit(1)

for raw in re.findall(r'"([^"]+)"', out.stdout):
    low = raw.lower()
    if "obsidian" in low or "steam" in low:
        continue
    if "/" not in raw:
        continue
    dest, path = raw.split("/", 1)
    path = "/" + path
    prop = run(["busctl", "--user", "get-property", dest, path,
                "org.kde.StatusNotifierItem", "Id"], t=0.2)
    blob = (prop.stdout if prop else "").lower()
    if 's "obs"' not in blob and "obs-tray" not in blob:
        continue
    if activate(dest, path):
        try:
            open(snifile, "w").write(raw)
        except Exception:
            pass
        sys.exit(0)
sys.exit(1)
PY
}

wait_for_window() {
  local n="${1:-40}" _
  for _ in $(seq 1 "$n"); do
    if obs_window_mapped; then
      hypr_focus_obs || true
      return 0
    fi
    sleep 0.05
  done
  return 1
}

# Show main window. SNI Activate toggles — only when unmapped.
show_window() {
  if obs_window_mapped; then
    log "already mapped → focus"
    hypr_focus_obs || true
    return 0
  fi
  log "unmapped → SNI Activate"
  sni_activate || true
  if wait_for_window 30; then
    log "window mapped after SNI"
    return 0
  fi
  rm -f "$SNIFILE"
  sni_activate || true
  if wait_for_window 20; then
    log "window mapped after SNI rediscover"
    return 0
  fi
  log "SNI failed to map window"
  return 1
}

kill_obs() {
  local p
  systemctl --user stop obs-tray.service >/dev/null 2>&1 || true
  for p in $(obs_pid || true); do
    kill "$p" 2>/dev/null || true
  done
  sleep 0.2
  for p in $(obs_pid || true); do
    kill -9 "$p" 2>/dev/null || true
  done
  rm -f "$PIDFILE" "$SNIFILE"
}

start_visible() {
  log "starting VISIBLE obs (no minimize)"
  # Do not use --minimize-to-tray — user asked for the application window.
  exec "$OBS" --disable-missing-files-check "$@"
}

# --- tray preload (systemd only) ---
if [ "${1:-}" = "--tray" ]; then
  shift
  ensure_hypr_env
  if obs_pid >/dev/null; then
    exit 0
  fi
  printf '%s\n' "$$" >"$PIDFILE"
  exec "$OBS" --minimize-to-tray --disable-missing-files-check "$@"
fi

# --- user launch (launcher / desktop) ---
ensure_hypr_env
log "launch begin wayland=${WAYLAND_DISPLAY:-} hypr=${HYPRLAND_INSTANCE_SIGNATURE:-} dbus=${DBUS_SESSION_BUS_ADDRESS:-}"

if obs_pid >/dev/null; then
  if show_window; then
    log "launch ok (raised)"
    exit 0
  fi
  # Warm tray exists but window will not appear — hard restart with a real window.
  log "raise failed → kill + visible start"
  kill_obs
  start_visible "$@"
fi

# Not running: open the real app window. Do NOT start minimized.
log "not running → visible start"
# Avoid racing a tray unit that would steal into minimize mode.
systemctl --user stop obs-tray.service >/dev/null 2>&1 || true
start_visible "$@"
