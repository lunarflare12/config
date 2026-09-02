{
  config,
  lib,
  pkgs,
  params,
  ...
}:

{
  nixpkgs.config = {
    allowUnfree = true;
    cudaCapabilities = [ "12.0" ];
  };

  nix.settings = {
    extra-substituters = [ "https://cuda-maintainers.cachix.org" ];
    extra-trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };

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
  boot.extraModprobeConfig = ''
    options nvidia NVreg_UsePageAttributeTable=1
  '';

  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    NVD_BACKEND = "direct";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __GL_GSYNC_ALLOWED = "1";
    __GL_VRR_ALLOWED = "1";
    __GL_SHADER_DISK_CACHE = "1";
    __GL_SHADER_DISK_CACHE_SKIP_CLEANUP = "1";
  };

  programs.gamemode = {
    enable = true;
    settings.gpu = {
      apply_gpu_optimisations = "accept-responsibility";
      gpu_device = 0;
      nv_powermizer_mode = 1;
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
    cudaPackages.cuda_nvcc
    cudaPackages.cuda_cudart
  ];
}
