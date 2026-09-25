{
  config,
  lib,
  pkgs,
  host,
  ...
}:

let
  shaderCacheDir = "/home/${host.userName}/.cache/steam-shadercache";
  dxvkCacheDir = "/home/${host.userName}/.cache/dxvk";
  nvidiaCacheDir = "/home/${host.userName}/.cache/nvidia";
  scripts = "/home/${host.userName}/.config/scripts";
  steamBinFile = "/home/${host.userName}/.local/share/aurora/steam-bin";

  # Host PATH must not expose the real Steam client — only the container launcher.
  steamHostShim = (pkgs.writeShellScriptBin "steam" ''
    exec ${scripts}/steam.sh "$@"
  '').overrideAttrs (old: {
    meta = (old.meta or { }) // {
      priority = 0;
    };
  });

  # Hide vendor steam.desktop from /run/current-system (HM owns the real entry).
  steamDesktopHide = pkgs.runCommand "steam-desktop-nodisplay" {
    meta.priority = 0;
  } ''
    mkdir -p "$out/share/applications"
    cat >"$out/share/applications/steam.desktop" <<'EOF'
    [Desktop Entry]
    Name=Steam
    Type=Application
    NoDisplay=true
    Hidden=true
    Exec=true
    EOF
  '';
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
        export __GLX_VENDOR_LIBRARY_NAME=nvidia
        export __GL_GSYNC_ALLOWED=0
        export __GL_VRR_ALLOWED=0
        export __GL_SYNC_TO_VBLANK=0
        export __GL_SHADER_DISK_CACHE=1
        # Never let the NVIDIA driver cull the disk cache on its own.
        export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
        export __GL_SHADER_DISK_CACHE_SIZE=34359738368
        export __GL_SHADER_DISK_CACHE_READ_ONLY_APP_NAME='steam_shader_cache;steamapp_merged_shader_cache'
        # Steam otherwise starts fossilize_replay with --num-threads=$(nproc)
        # and the desktop freezes while Overwatch shaders compile.
        export FOSSILIZE_CONCURRENCY=2
        # Session GBM_BACKEND=nvidia-drm breaks Steam CEF on XWayland (black window).
        unset GBM_BACKEND
        unset NVD_BACKEND
        mkdir -p ${lib.escapeShellArg shaderCacheDir} ${lib.escapeShellArg dxvkCacheDir}
      '';
    };
  };

  # steam-fhs → real client; `steam` → container shim (priority 0 beats programs.steam).
  environment.systemPackages = [
    steamHostShim
    steamDesktopHide
    (pkgs.runCommand "steam-fhs-bin" { } ''
      mkdir -p "$out/bin"
      ln -s ${lib.getExe config.programs.steam.package} "$out/bin/steam-fhs"
    '')
  ];

  # Absolute FHS path for containers/steam (never the host shim).
  system.activationScripts.aurora-steam-bin = ''
    mkdir -p /home/${host.userName}/.local/share/aurora
    printf '%s\n' ${lib.escapeShellArg (lib.getExe config.programs.steam.package)} > ${steamBinFile}
    chown ${host.userName}:users ${steamBinFile} /home/${host.userName}/.local/share/aurora
  '';

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
    "d ${nvidiaCacheDir} 0755 ${host.userName} users -"
    "d ${nvidiaCacheDir}/overwatch 0755 ${host.userName} users -"
    "d ${nvidiaCacheDir}/terraria 0755 ${host.userName} users -"
    "d ${nvidiaCacheDir}/albion 0755 ${host.userName} users -"
    # Exclude from systemd-tmpfiles-clean. Never age-delete shader/DXVK caches.
    # boot.tmp.cleanOnBoot only wipes /tmp. These live on /home and survive
    # nixos-rebuild, nix-collect-garbage, and reboot.
    "x ${shaderCacheDir}"
    "x ${shaderCacheDir}/*"
    "x ${dxvkCacheDir}"
    "x ${dxvkCacheDir}/*"
    "x ${nvidiaCacheDir}"
    "x ${nvidiaCacheDir}/*"
  ];
}
