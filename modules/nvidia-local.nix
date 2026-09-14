{
  config,
  lib,
  pkgs,
  params,
  ...
}:

# Writable NVIDIA module. modules/nvidia.nix is root-owned and unused.
{
  nixpkgs.config.allowUnfree = true;

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = [ pkgs.nvidia-vaapi-driver ];
    extraPackages32 = [ pkgs.pkgsi686Linux.nvidia-vaapi-driver ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaPersistenced = true;
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  boot.kernelParams = [ "nvidia-drm.fbdev=1" ];

  # Aquamarine splits AQ_DRM_DEVICES on ":", so PCI by-path names cannot be used.
  services.udev.extraRules = ''
    SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ATTRS{vendor}=="0x10de", SYMLINK+="dri/nvidia-card"
  '';
  boot.extraModprobeConfig = ''
    options nvidia NVreg_RegistryDwords="RMUseSwI2c=0x01;RMI2cSpeed=100"
  '';

  environment.sessionVariables = {
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
    __GL_SHADER_DISK_CACHE_SIZE = "8589934592";
  };

  programs.gamescope = {
    enable = true;
    capSysNice = true;
  };

  programs.gamemode = {
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

  hardware.steam-hardware.enable = true;

  users.users = lib.mapAttrs (_: _: {
    extraGroups = [
      "video"
      "gamemode"
    ];
  }) params.users;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    mangohud
    gamescope
  ];
}
