#!/run/current-system/sw/bin/bash
# Intentionally inert. Unloading csgo-vulkan-fix and re-dofile'ing
# decorations/animations here ran on every GameMode end, so closing
# Overwatch sat on a stream of "plugin restarted" notices.
exit 0
