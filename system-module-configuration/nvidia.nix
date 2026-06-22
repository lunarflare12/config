{ driver, graphics }:
{ config, lib, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  boot.blacklistedKernelModules = [ "nouveau" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false;
    open = true;
    nvidiaPersistenced = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver driver;
  };

  services.xserver.enable = lib.mkIf graphics.xserver true;
  services.xserver.videoDrivers = [ "nvidia" ];

  environment.sessionVariables = lib.mkIf graphics.wayland {
    NIXOS_OZONE_WAYLAND = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    LIBVA_DRIVER_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
  };
}
