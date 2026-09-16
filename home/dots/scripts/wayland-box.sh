#!/usr/bin/env bash
# Run a host binary on Hyprland inside Linux namespaces (bwrap).
# Isolated HOME, no X11, no Hyprland IPC. Wayland + GPU + PipeWire only.
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
wayland-box [--name NAME] [--offline] [--home DIR] [--bind PATH]... [--] CMD [ARGS...]

  --name     sandbox id (default: command basename)
  --offline  no network
  --home     override isolated HOME
  --bind     extra host path, mounted at the same place (repeatable)
EOF
  exit 2
}

find_store_bin() {
  local name="$1" glob="$2" p
  p=$(command -v "$name" 2>/dev/null || true)
  if [[ -n "$p" && -x "$p" ]]; then
    printf '%s\n' "$p"
    return 0
  fi
  for p in /nix/store/$glob; do
    if [[ -x "$p" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  done
  return 1
}

NAME=""
OFFLINE=0
BOX_HOME=""
EXTRA_BINDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage ;;
    --name)
      NAME="${2:-}"
      shift 2
      ;;
    --offline)
      OFFLINE=1
      shift
      ;;
    --home)
      BOX_HOME="${2:-}"
      shift 2
      ;;
    --bind)
      EXTRA_BINDS+=("${2:-}")
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "wayland-box: unknown flag $1" >&2
      usage
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -gt 0 ]] || usage

BWRAP=$(find_store_bin bwrap "*-bubblewrap-*/bin/bwrap") || {
  echo "wayland-box: bwrap not found" >&2
  exit 1
}
PROXY=$(find_store_bin xdg-dbus-proxy "*-xdg-dbus-proxy-*/bin/xdg-dbus-proxy" || true)

CMD_BASENAME=$(basename -- "$1")
[[ -n "$NAME" ]] || NAME="$CMD_BASENAME"
NAME=${NAME//[^A-Za-z0-9._-]/_}

HOST_HOME="${HOME:?}"
HOST_UID=$(id -u)
HOST_RT="${XDG_RUNTIME_DIR:-/run/user/$HOST_UID}"
WL="${WAYLAND_DISPLAY:-wayland-1}"
BOX_HOME="${BOX_HOME:-$HOST_HOME/.local/share/wayland-box/$NAME}"
SANDBOX_RT="$HOST_RT/wayland-box-$NAME"

mkdir -p "$BOX_HOME" "$SANDBOX_RT"
mkdir -p "$HOST_HOME/Downloads"

cleanup() {
  if [[ -n "${PROXY_PID:-}" ]]; then
    kill "$PROXY_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
  fi
  rm -rf "$SANDBOX_RT"
}
trap cleanup EXIT INT TERM

DBUS_SRC="${DBUS_SESSION_BUS_ADDRESS:-unix:path=$HOST_RT/bus}"
if [[ -n "$PROXY" && -x "$PROXY" ]]; then
  "$PROXY" "$DBUS_SRC" "$SANDBOX_RT/bus" --filter \
    --talk=org.freedesktop.DBus \
    --talk=org.freedesktop.Notifications \
    --talk=org.freedesktop.ScreenSaver \
    --talk=org.freedesktop.portal.Desktop \
    --talk=org.freedesktop.portal.Documents \
    --talk=org.freedesktop.portal.FileChooser \
    --talk=org.freedesktop.portal.OpenURI \
    --talk=org.freedesktop.portal.Settings \
    --talk=org.freedesktop.portal.IBus \
    --talk=org.freedesktop.portal.IBus.Portal \
    --talk=org.freedesktop.impl.portal.PermissionStore \
    --call=org.freedesktop.portal.*=* \
    --broadcast=org.freedesktop.portal.*=@/org/freedesktop/portal/* \
    >/dev/null 2>&1 &
  PROXY_PID=$!
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -S "$SANDBOX_RT/bus" ]] && break
    sleep 0.05
  done
fi

args=(
  --unshare-all
  --die-with-parent
  --new-session
  --unshare-uts
  --hostname "box-$NAME"
  --proc /proc
  --dev /dev
  --tmpfs /tmp
  --tmpfs /run/user
  --dir "$HOST_RT"
  --bind "$BOX_HOME" "$HOST_HOME"
  --bind "$HOST_HOME/Downloads" "$HOST_HOME/Downloads"
  --ro-bind /nix /nix
  --ro-bind /run/current-system /run/current-system
  --ro-bind /etc /etc
  --ro-bind-try /bin /bin
  --ro-bind-try /usr /usr
  --ro-bind-try /run/opengl-driver /run/opengl-driver
  --ro-bind-try /run/opengl-driver-32 /run/opengl-driver-32
  --ro-bind-try /run/nscd /run/nscd
  --ro-bind-try /sys /sys
  --dev-bind-try /dev/dri /dev/dri
  --dev-bind-try /dev/nvidia0 /dev/nvidia0
  --dev-bind-try /dev/nvidiactl /dev/nvidiactl
  --dev-bind-try /dev/nvidia-modeset /dev/nvidia-modeset
  --dev-bind-try /dev/nvidia-uvm /dev/nvidia-uvm
  --dev-bind-try /dev/nvidia-uvm-tools /dev/nvidia-uvm-tools
  --bind-try "$HOST_RT/$WL" "$HOST_RT/$WL"
  --bind-try "$HOST_RT/$WL.lock" "$HOST_RT/$WL.lock"
  --bind-try "$HOST_RT/pipewire-0" "$HOST_RT/pipewire-0"
  --bind-try "$HOST_RT/pipewire-0.lock" "$HOST_RT/pipewire-0.lock"
  --bind-try "$HOST_RT/pulse" "$HOST_RT/pulse"
  --ro-bind-try "$HOST_HOME/.local/share/fonts" "$HOST_HOME/.local/share/fonts"
  --ro-bind-try "$HOST_HOME/.icons" "$HOST_HOME/.icons"
  --ro-bind-try "$HOST_HOME/.config/fontconfig" "$HOST_HOME/.config/fontconfig"
  --chdir "$HOST_HOME"
  --setenv HOME "$HOST_HOME"
  --setenv XDG_RUNTIME_DIR "$HOST_RT"
  --setenv XDG_SESSION_TYPE wayland
  --setenv WAYLAND_DISPLAY "$WL"
  --setenv QT_QPA_PLATFORM wayland
  --setenv GDK_BACKEND wayland
  --setenv SDL_VIDEODRIVER wayland
  --setenv MOZ_ENABLE_WAYLAND 1
  --setenv ELECTRON_OZONE_PLATFORM_HINT wayland
  --unsetenv DISPLAY
  --unsetenv XAUTHORITY
  --unsetenv HYPRLAND_INSTANCE_SIGNATURE
  --unsetenv SWAYSOCK
  --unsetenv I3SOCK
)

if [[ $OFFLINE -eq 0 ]]; then
  args+=(--share-net)
fi

if [[ -S "$SANDBOX_RT/bus" ]]; then
  args+=(--bind "$SANDBOX_RT/bus" "$HOST_RT/bus")
  args+=(--setenv DBUS_SESSION_BUS_ADDRESS "unix:path=$HOST_RT/bus")
fi

for p in "${EXTRA_BINDS[@]+"${EXTRA_BINDS[@]}"}"; do
  [[ -e "$p" ]] || continue
  args+=(--bind "$p" "$p")
done

"$BWRAP" "${args[@]}" -- "$@"
