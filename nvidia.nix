{
  config,
  pkgs,
  ...
}:

{
  nixpkgs.config = {
    allowUnfree = true;
    # RTX 5060 Ti is Blackwell (sm_120). Used when CUDA packages are built.
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
    extraPackages = with pkgs; [
      nvidia-vaapi-driver
      vaapiVdpau
      libvdpau-va-gl
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [
      nvidia-vaapi-driver
    ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Required for Wayland and KMS.
    modesetting.enable = true;

    # Saves VRAM across suspend; needed on desktop if sleep corrupts the display.
    powerManagement.enable = true;
    # Laptop-only (PRIME offload). 5060 Ti is a discrete desktop GPU.
    powerManagement.finegrained = false;

    # Blackwell (RTX 50) requires NVIDIA's open kernel modules.
    open = true;

    nvidiaSettings = true;
    nvidiaPersistenced = true;

    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };

  hardware.nvidia-container-toolkit.enable = true;

  boot.kernelParams = [
    "nvidia-drm.fbdev=1"
  ];

  boot.extraModprobeConfig = ''
    options nvidia NVreg_UsePageAttributeTable=1
    options nvidia NVreg_EnableGpuFirmware=1
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
    settings = {
      general = {
        renice = 10;
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0;
        nv_powermizer_mode = 1;
      };
    };
  };

  hardware.steam-hardware.enable = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
    vulkan-tools
    libva-utils
    mangohud
    gamescope

    cudaPackages.cuda_nvcc
    cudaPackages.cuda_cudart
    cudaPackages.cuda_cccl
    cudaPackages.cuda_nvrtc
    cudaPackages.libcublas
  ];
}
