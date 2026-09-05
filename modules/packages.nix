{ lib, pkgs, params, ... }:

let
  packages = params.packages or [ ];
  has = name: lib.elem name packages;
  steamUser = lib.head (lib.attrNames params.users);
  shaderCacheDir = "/home/${steamUser}/.cache/steam-shadercache";
  dxvkCacheDir = "/home/${steamUser}/.cache/dxvk";

  packageMap = {
    terraform = pkgs.terraform;
    ansible = pkgs.ansible;
    go = pkgs.go;
    nodejs_latest = pkgs.nodejs_latest;
    python3 = pkgs.python3;
    telegram-desktop = pkgs.telegram-desktop;
    idea-oss = pkgs.jetbrains.idea-oss;
    vscode = pkgs.vscode;
    code-cursor = pkgs.code-cursor;
    keymapp = pkgs.keymapp;
    obsidian = pkgs.obsidian;
    google-chrome = pkgs.google-chrome;
    kubectl = pkgs.kubectl;
    k9s = pkgs.k9s;
    awscli2 = pkgs.awscli2;
    vesktop = pkgs.vesktop;
  };
in
{
  nixpkgs.config.permittedInsecurePackages = lib.optionals (has "idea-oss") [
    "idea-oss-2025.3.4"
  ];

  hardware.keyboard.zsa.enable = has "keymapp";

  virtualisation.docker.enable = has "docker";

  programs.steam = lib.mkIf (has "steam") {
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
        export __GL_SYNC_TO_VBLANK=0
        export __GL_SHADER_DISK_CACHE=1
        export __GL_SHADER_DISK_CACHE_SKIP_CLEANUP=1
        export __GL_SHADER_DISK_CACHE_SIZE=10737418240
        export DXVK_STATE_CACHE=1
        export DXVK_STATE_CACHE_PATH="${dxvkCacheDir}"
        mkdir -p "${shaderCacheDir}" "${dxvkCacheDir}"
      '';
    };
  };

  # Steam treats a library as read-only if any mount of that block device
  # is ro (/nix/store on the root disk). Kernel overlay gives /steam a
  # new device id without FUSE, so game loads stay on native ext4.
  users.groups.steam = lib.mkIf (has "steam") { };

  fileSystems."/steam" = lib.mkIf (has "steam") {
    overlay = {
      lowerdir = [ "/var/lib/steam-library" ];
      upperdir = "/var/lib/steam-upper";
      workdir = "/var/lib/steam-work";
    };
    options = [
      "nofail"
      "index=off"
      "xino=off"
    ];
  };

  # Overlay inodes change across remounts, so NVIDIA/Steam rebuilds the
  # 16G shader cache after every reboot. Keep it on real ext4 under /home.
  fileSystems."/steam/steamapps/shadercache" = lib.mkIf (has "steam") {
    device = shaderCacheDir;
    fsType = "none";
    options = [
      "bind"
      "nofail"
    ];
    depends = [ "/steam" ];
  };

  systemd.tmpfiles.rules = lib.optionals (has "steam") [
    "d /var/lib/steam-library 0775 ${steamUser} steam -"
    "d /var/lib/steam-library/steamapps 0775 ${steamUser} steam -"
    "d /var/lib/steam-library/steamapps/common 0775 ${steamUser} steam -"
    "d /var/lib/steam-library/steamapps/downloading 0775 ${steamUser} steam -"
    "d /var/lib/steam-library/steamapps/temp 0775 ${steamUser} steam -"
    "d /var/lib/steam-upper 0775 ${steamUser} steam -"
    "d /var/lib/steam-work 0700 root root -"
    "d ${shaderCacheDir} 0755 ${steamUser} users -"
    "d ${dxvkCacheDir} 0755 ${steamUser} users -"
  ];

  environment.systemPackages = map (name: packageMap.${name}) (
    lib.filter (name: builtins.hasAttr name packageMap) packages
  );

  users.users = lib.mapAttrs (_: _: {
    extraGroups = lib.optional (has "docker") "docker" ++ lib.optional (has "steam") "steam";
  }) params.users;
}
