{
  lib,
  pkgs,
  host,
  desktopEnv,
  ...
}:

let
  shaderCacheDir = "/home/${host.userName}/.cache/steam-shadercache";
  dxvkCacheDir = "/home/${host.userName}/.cache/dxvk";
  glExports = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (key: value: "export ${key}=${lib.escapeShellArg value}") desktopEnv.nvidiaGl
  );
in
lib.mkIf (host.enabled "steam") {
  users.groups.steam = { };

  programs.steam = {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    extraPackages = [
      pkgs.gamemode
      pkgs.gamescope
      pkgs.mangohud
    ];
    gamescopeSession.enable = false;
    package = pkgs.steam.override {
      extraBwrapArgs = [
        "--bind /steam /steam"
        "--bind ${shaderCacheDir} ${shaderCacheDir}"
        "--bind ${dxvkCacheDir} ${dxvkCacheDir}"
      ];
      extraProfile = ''
        export PROTON_ENABLE_NVAPI=1
        export PROTON_HIDE_NVIDIA_GPU=0
        export PROTON_ENABLE_NGX_UPDATER=0
        export DXVK_STATE_CACHE=1
        export DXVK_STATE_CACHE_PATH=${lib.escapeShellArg dxvkCacheDir}
        ${glExports}
        mkdir -p ${lib.escapeShellArg shaderCacheDir} ${lib.escapeShellArg dxvkCacheDir}
      '';
    };
  };

  # Steam treats a library as read-only if any mount of that block device
  # is ro (/nix/store on the root disk). Overlay gives /steam a new device
  # id without FUSE. Shader cache stays on real ext4 under /home.
  fileSystems."/steam" = {
    overlay = {
      lowerdir = [ "/var/lib/steam-library" ];
      upperdir = "/var/lib/steam-upper";
      workdir = "/var/lib/steam-work";
    };
    options = [
      "nofail"
      "index=off"
      "xino=off"
      "metacopy=on"
    ];
  };

  fileSystems."/steam/steamapps/shadercache" = {
    device = shaderCacheDir;
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
    depends = [ "/steam" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/steam-library 0775 ${host.userName} steam -"
    "d /var/lib/steam-library/steamapps 0775 ${host.userName} steam -"
    "d /var/lib/steam-library/steamapps/common 0775 ${host.userName} steam -"
    "d /var/lib/steam-library/steamapps/downloading 0775 ${host.userName} steam -"
    "d /var/lib/steam-library/steamapps/temp 0775 ${host.userName} steam -"
    "d /var/lib/steam-upper 0775 ${host.userName} steam -"
    "d /var/lib/steam-work 0700 root root -"
    "d ${shaderCacheDir} 0755 ${host.userName} users -"
    "d ${dxvkCacheDir} 0755 ${host.userName} users -"
  ];
}
