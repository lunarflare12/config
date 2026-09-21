#!/usr/bin/env bash
# Steam is already XWayland here. CEF without GPU paints the library on the CPU
# and stalls the whole desktop (~1 core at 2448x1034). Games still use Proton.
export GDK_BACKEND=x11
exec /run/current-system/sw/bin/steam "$@"
