driver: { config, ... }: {
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

  services.xserver.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
}
