{
  config,
  pkgs,
  desktopEnv,
  ...
}:

{
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = [ pkgs.nvidia-vaapi-driver ];
      extraPackages32 = [ pkgs.pkgsi686Linux.nvidia-vaapi-driver ];
    };
    nvidia = {
      modesetting.enable = true;
      powerManagement.enable = false;
      open = true;
      nvidiaPersistenced = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
    nvidia-container-toolkit.enable = true;
    steam-hardware.enable = true;
  };

  services = {
    xserver.videoDrivers = [ "nvidia" ];
    udev.extraRules = ''
      SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ATTRS{vendor}=="0x10de", SYMLINK+="dri/nvidia-card"
    '';
  };

  boot = {
    kernelParams = [ "nvidia-drm.fbdev=1" ];
    extraModprobeConfig = ''
      options nvidia NVreg_RegistryDwords="RMUseSwI2c=0x01;RMI2cSpeed=100"
    '';
  };

  programs = {
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    gamemode = {
      enable = true;
      settings = {
        general = {
          renice = 10;
          ioprio = 0;
        };
        gpu = {
          apply_gpu_optimisations = "accept-responsibility";
          gpu_device = 0;
          nv_powermizer_mode = 1;
        };
      };
    };
  };

  environment = {
    sessionVariables = desktopEnv.nvidiaGl;
    systemPackages = [
      pkgs.nvtopPackages.nvidia
      pkgs.mangohud
    ];
  };
}
