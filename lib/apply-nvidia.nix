driver: { config, ... }: {
  boot.initrd.availableKernelModules = [
    "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm"
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver driver;
  };

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
}
