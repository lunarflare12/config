#!/usr/bin/env bash
# Shared dark-theme helpers for container / host launchers.
# Prefer the HM-generated file; always fill the keys compose/entrypoint expect.

if [[ -f "${HOME}/.config/aurora/space-env.sh" ]]; then
  # shellcheck disable=SC1091
  source "${HOME}/.config/aurora/space-env.sh"
fi

export GTK_THEME="${GTK_THEME:-WhiteSur-Dark}"
export GTK_APPLICATION_PREFER_DARK_THEME="${GTK_APPLICATION_PREFER_DARK_THEME:-1}"
export GTK_ICON_THEME="${GTK_ICON_THEME:-WhiteSur-dark}"
export QT_QPA_PLATFORMTHEME="${QT_QPA_PLATFORMTHEME:-qt6ct}"
export QT_STYLE_OVERRIDE="${QT_STYLE_OVERRIDE:-kvantum}"
export QT_QUICK_CONTROLS_STYLE="${QT_QUICK_CONTROLS_STYLE:-Fusion}"
export ADW_DEBUG_COLOR_SCHEME="${ADW_DEBUG_COLOR_SCHEME:-prefer-dark}"
export ELECTRON_FORCE_DARK="${ELECTRON_FORCE_DARK:-1}"
export GTK_USE_PORTAL="${GTK_USE_PORTAL:-0}"
export COLOR_SCHEME="${COLOR_SCHEME:-prefer-dark}"

space_docker_env() {
  printf '%s' \
    "-e GTK_THEME=${GTK_THEME} " \
    "-e GTK_APPLICATION_PREFER_DARK_THEME=${GTK_APPLICATION_PREFER_DARK_THEME} " \
    "-e GTK_ICON_THEME=${GTK_ICON_THEME} " \
    "-e QT_QPA_PLATFORMTHEME=${QT_QPA_PLATFORMTHEME} " \
    "-e QT_STYLE_OVERRIDE=${QT_STYLE_OVERRIDE} " \
    "-e QT_QUICK_CONTROLS_STYLE=${QT_QUICK_CONTROLS_STYLE} " \
    "-e ADW_DEBUG_COLOR_SCHEME=${ADW_DEBUG_COLOR_SCHEME} " \
    "-e ELECTRON_FORCE_DARK=${ELECTRON_FORCE_DARK} " \
    "-e GTK_USE_PORTAL=${GTK_USE_PORTAL} " \
    "-e COLOR_SCHEME=${COLOR_SCHEME}"
}

# Wayland-only. Isolated apps must not inherit a host DISPLAY / X11 socket.
space_display_env() {
  printf '%s' \
    "-e XDG_RUNTIME_DIR=/tmp/xdg " \
    "-e WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1} " \
    "-e GDK_BACKEND=wayland " \
    "-e MOZ_ENABLE_WAYLAND=1 " \
    "-e QT_QPA_PLATFORM=wayland"
}

space_load_apps_env() {
  local envf="${HOME}/containers/apps/.env"
  if [[ -f "$envf" ]]; then
    set -a
    # shellcheck disable=SC1090
    source "$envf"
    set +a
  fi
}
