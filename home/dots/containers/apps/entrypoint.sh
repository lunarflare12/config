#!/bin/sh
set -eu

runtime="${XDG_RUNTIME_DIR:-/tmp/xdg}"
home="${HOME:-/home/app}"

mkdir -p "$home/Downloads" "$home/ipc"

# Prefer host session bus when mounted (StatusNotifierWatcher / tray).
# Apps that don't mount /run/user/1000/bus keep a private dbus-daemon.
host_bus="/run/user/1000/bus"
if [ -S "$host_bus" ]; then
  dbus_addr="unix:path=$host_bus"
elif [ -S "$runtime/bus" ]; then
  dbus_addr="unix:path=$runtime/bus"
else
  dbus-daemon --session --fork --address="unix:path=$runtime/bus"
  dbus_addr="unix:path=$runtime/bus"
fi

# Chrome "Show in folder" talks to FileManager1 on this session bus.
# Without an owner it fails silently and never calls xdg-open.
fm1=""
for cand in \
  /usr/local/bin/filemanager1-stub \
  "$home/.local/bin/filemanager1-stub" \
  /home/app/.local/bin/filemanager1-stub
do
  if [ -x "$cand" ]; then
    fm1=$cand
    break
  fi
done
if [ -n "$fm1" ]; then
  DBUS_SESSION_BUS_ADDRESS="$dbus_addr" HOME="$home" "$fm1" &
fi

# Dark theme defaults when compose / docker exec forget to pass them.
# Keep in sync with lib/desktop-env.nix gtkQt + lib/space.nix darkTheme.
export GTK_THEME="${GTK_THEME:-WhiteSur-Dark}"
export GTK_APPLICATION_PREFER_DARK_THEME="${GTK_APPLICATION_PREFER_DARK_THEME:-1}"
export GTK_ICON_THEME="${GTK_ICON_THEME:-WhiteSur-dark}"
export ADW_DEBUG_COLOR_SCHEME="${ADW_DEBUG_COLOR_SCHEME:-prefer-dark}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"
export QT_STYLE_OVERRIDE="${QT_STYLE_OVERRIDE:-kvantum}"
export QT_QUICK_CONTROLS_STYLE="${QT_QUICK_CONTROLS_STYLE:-Fusion}"
export ELECTRON_FORCE_DARK="${ELECTRON_FORCE_DARK:-1}"
export GTK_USE_PORTAL="${GTK_USE_PORTAL:-0}"
export COLOR_SCHEME="${COLOR_SCHEME:-prefer-dark}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"
export GDK_BACKEND="${GDK_BACKEND:-wayland}"
export MOZ_ENABLE_WAYLAND="${MOZ_ENABLE_WAYLAND:-1}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}"
unset DISPLAY

# Persist dark GTK into the mounted home so apps that read settings.ini
# (LibreOffice, Firefox, Electron) stay dark even without env vars.
mkdir -p "$home/.config/gtk-3.0" "$home/.config/gtk-4.0"
gtk_ini="$home/.config/gtk-3.0/settings.ini"
cat >"$gtk_ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=WhiteSur-Dark
gtk-icon-theme-name=WhiteSur-dark
EOF
cp -f "$gtk_ini" "$home/.config/gtk-4.0/settings.ini"

# IDEA DirectoryLock is on the mounted home. After the container dies the
# next PID 12 is "still running" and the IDE refuses to start.
case "${1##*/}" in
  idea | idea.sh | .idea-wrapped)
    rm -f "$home/.config/JetBrains/"IntelliJIdea*/.lock
    rm -f "$home/.cache/JetBrains/"IntelliJIdea*/.port
    ;;
  qbittorrent | .qbittorrent-wrapped)
    rm -f "$home/.config/qBittorrent/lockfile"
    ;;
esac

# Open WebUI lives on the shared llm network. Bind the same URL Chrome
# uses on the host so http://127.0.0.1:3000 works inside the browser netns.
fwd_pid=""
if getent hosts open-webui >/dev/null 2>&1; then
  socat="${SOCAT_BIN:-}"
  if [ ! -x "$socat" ]; then
    socat=$(ls -1 /nix/store/*-socat-*/bin/socat 2>/dev/null | head -n 1)
  fi
  if [ -n "$socat" ] && [ -x "$socat" ]; then
    "$socat" TCP-LISTEN:3000,fork,reuseaddr,bind=127.0.0.1 TCP:open-webui:8080 &
    fwd_pid=$!
  fi
fi

env \
  -u DISPLAY \
  DBUS_SESSION_BUS_ADDRESS="$dbus_addr" \
  HOME="$home" \
  XDG_RUNTIME_DIR="$runtime" \
  WAYLAND_DISPLAY="$WAYLAND_DISPLAY" \
  GDK_BACKEND="$GDK_BACKEND" \
  MOZ_ENABLE_WAYLAND="$MOZ_ENABLE_WAYLAND" \
  QT_QPA_PLATFORM="$QT_QPA_PLATFORM" \
  GTK_THEME="$GTK_THEME" \
  GTK_APPLICATION_PREFER_DARK_THEME="$GTK_APPLICATION_PREFER_DARK_THEME" \
  GTK_ICON_THEME="$GTK_ICON_THEME" \
  ADW_DEBUG_COLOR_SCHEME="$ADW_DEBUG_COLOR_SCHEME" \
  QT_QPA_PLATFORMTHEME="$QT_QPA_PLATFORMTHEME" \
  QT_STYLE_OVERRIDE="$QT_STYLE_OVERRIDE" \
  QT_QUICK_CONTROLS_STYLE="$QT_QUICK_CONTROLS_STYLE" \
  ELECTRON_FORCE_DARK="$ELECTRON_FORCE_DARK" \
  GTK_USE_PORTAL="$GTK_USE_PORTAL" \
  COLOR_SCHEME="$COLOR_SCHEME" \
  "$@" &
pid=$!
trap 'kill -TERM "$pid" ${fwd_pid:+"$fwd_pid"} 2>/dev/null; wait "$pid"' TERM INT
wait "$pid"
