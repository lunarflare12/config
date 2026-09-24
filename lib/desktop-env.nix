{
  # Session + portal dark preference. Spaces / containers reuse this via lib/space.nix.
  gtkQt = {
    GTK_THEME = "WhiteSur-Dark";
    GTK_APPLICATION_PREFER_DARK_THEME = "1";
    GTK_ICON_THEME = "WhiteSur-dark";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    QT_QUICK_CONTROLS_STYLE = "Fusion";
    ADW_DEBUG_COLOR_SCHEME = "prefer-dark";
  };

  wayland = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
  };

  nvidiaGl = {
    AQ_DRM_DEVICES = "/dev/dri/nvidia-card";
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "0";
    __GL_VRR_ALLOWED = "0";
    __GL_SYNC_TO_VBLANK = "0";
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
    __GL_SHADER_DISK_CACHE_SIZE = "34359738368";
  };
}
