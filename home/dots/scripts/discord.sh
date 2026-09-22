#!/usr/bin/env bash
unset NIXOS_OZONE_WL
unset ELECTRON_OZONE_PLATFORM_HINT
export GDK_BACKEND=x11
exec /etc/profiles/per-user/dd/bin/discord "$@"
