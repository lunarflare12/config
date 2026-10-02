#!/bin/sh
set -eu

runtime="${XDG_RUNTIME_DIR:-/tmp/xdg}"
home="${HOME:-/home/telegram}"
workdir="$home/.local/share/TelegramDesktop"

mkdir -p "$runtime" "$home/Downloads" "$workdir"

rm -f "$runtime/bus" "$workdir/lock" "$workdir/.lock"

if [ -S "$runtime/notify.sock" ]; then
  bus="$runtime/notify.sock"
elif [ ! -S "$runtime/bus" ]; then
  dbus-daemon --session --fork --address="unix:path=$runtime/bus"
  bus="$runtime/bus"
else
  bus="$runtime/bus"
fi

link=""
if [ -s /ipc/telegram.url ]; then
  link=$(cat /ipc/telegram.url)
  : > /ipc/telegram.url
fi

# Official Telegram night mode follows Qt colorScheme → GtkSettings.
# Fusion/kvantum overrides report light and pin the day theme.
mkdir -p "$home/.config/gtk-3.0" "$home/.config/gtk-4.0"
gtk_ini="$home/.config/gtk-3.0/settings.ini"
cat > "$gtk_ini" <<'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
gtk-theme-name=WhiteSur-Dark-alt
gtk-icon-theme-name=WhiteSur-dark
EOF
cp "$gtk_ini" "$home/.config/gtk-4.0/settings.ini"

set -- env -u QT_STYLE_OVERRIDE -u QT_QUICK_CONTROLS_STYLE -u QT_QPA_PLATFORMTHEME \
  DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
  HOME="$home" \
  XDG_RUNTIME_DIR="$runtime" \
  WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}" \
  PULSE_SERVER="${PULSE_SERVER:-unix:/tmp/pulse-native}" \
  LANG="${LANG:-ru_RU.UTF-8}" \
  LC_ALL="${LC_ALL:-ru_RU.UTF-8}" \
  QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland}" \
  QT_AUTO_SCREEN_SCALE_FACTOR=1 \
  XDG_CURRENT_DESKTOP="${XDG_CURRENT_DESKTOP:-GNOME}" \
  GTK_THEME="${GTK_THEME:-WhiteSur-Dark-alt:dark}" \
  GTK_APPLICATION_PREFER_DARK_THEME=1 \
  ADW_DEBUG_COLOR_SCHEME=prefer-dark \
  GTK_USE_PORTAL=0 \
  COLOR_SCHEME=prefer-dark \
  /opt/Telegram/Telegram -workdir "$workdir"

if [ -n "$link" ]; then
  exec "$@" "$link"
fi
exec "$@"
