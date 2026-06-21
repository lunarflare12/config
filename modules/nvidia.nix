{ driver, graphics }: { config, lib, ... }: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver driver;
  };

  services.xserver.enable = lib.mkIf graphics.xserver true;
  services.xserver.videoDrivers = lib.mkIf graphics.xserver [ "nvidia" ];

  environment.sessionVariables = lib.mkIf graphics.wayland {
    NIXOS_OZONE_WAYLAND = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
  };
}
