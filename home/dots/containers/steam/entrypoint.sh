#!/bin/sh
set -eu

runtime="${XDG_RUNTIME_DIR:-/tmp/xdg}"
home="${HOME:-/home/dd}"

mkdir -p \
  "$runtime" \
  "$home/.local/share/Steam" \
  "$home/.steam" \
  "$home/.cache/steam-shadercache" \
  "$home/.cache/dxvk" \
  "$home/.config/dxvk"

# Tray icon is a StatusNotifier item. It only shows in the bar if Steam
# talks to the host session bus, where Quickshell is the watcher.
# A private bus at /tmp/xdg/bus hides the icon.
host_bus="/run/user/1000/bus"
if [ -S "$host_bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$host_bus"
elif [ -S "$runtime/bus" ]; then
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
else
  dbus-daemon --session --fork --address="unix:path=$runtime/bus"
  export DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus"
fi

# Drop session GBM — Steam CEF goes black with nvidia-drm GBM on XWayland.
unset GBM_BACKEND NVD_BACKEND || true

# Keep this minimal: Steam locks setenv after start; extra DXVK/GL here breaks applaunch.
export HOME="$home"
export XDG_RUNTIME_DIR="$runtime"
export GDK_BACKEND="${GDK_BACKEND:-x11}"
export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-xcb}"
export STEAM_FORCE_DESKTOPUI_SCALING="${STEAM_FORCE_DESKTOPUI_SCALING:-1}"
export __GLX_VENDOR_LIBRARY_NAME="${__GLX_VENDOR_LIBRARY_NAME:-nvidia}"
export STEAM_CONTAINER=1
export SSL_CERT_FILE="${SSL_CERT_FILE:-/etc/ssl/certs/ca-bundle.crt}"
export NIX_SSL_CERT_FILE="${NIX_SSL_CERT_FILE:-$SSL_CERT_FILE}"
export CURL_CA_BUNDLE="${CURL_CA_BUNDLE:-$SSL_CERT_FILE}"
export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json:/run/opengl-driver-32/share/vulkan/icd.d/nvidia_icd.json}"
export VK_DRIVER_FILES="${VK_DRIVER_FILES:-$VK_ICD_FILENAMES}"
export LD_LIBRARY_PATH="/run/opengl-driver/lib:/run/opengl-driver-32/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PULSE_SERVER="${PULSE_SERVER:-unix:/run/user/1000/pulse/native}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-pulseaudio}"

exec "$@"
