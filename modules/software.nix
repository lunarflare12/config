{
  lib,
  pkgs,
  params,
  ...
}:

let
  packages = params.packages or [ ];
  has = name: lib.elem name packages;
  user = lib.head (lib.attrNames params.users);
  shaderCacheDir = "/home/${user}/.cache/steam-shadercache";
  dxvkCacheDir = "/home/${user}/.cache/dxvk";
  shaderCacheSize = (import ../lib/desktop-env.nix).nvidiaGl.__GL_SHADER_DISK_CACHE_SIZE;
  scripts = "/home/${user}/.config/scripts";

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
    btop = pkgs.btop;
    vlc = pkgs.vlc;
    vagrant = pkgs.vagrant;
    discord = pkgs.discord;
    spotify = pkgs.spotify;
    xournalpp = pkgs.xournalpp;
    prismlauncher = pkgs.prismlauncher;
  };

  mapped = lib.filter (name: builtins.hasAttr name packageMap) packages;
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
        export __GL_SHADER_DISK_CACHE_SIZE=${shaderCacheSize}
        export DXVK_STATE_CACHE=1
        export DXVK_STATE_CACHE_PATH="${dxvkCacheDir}"
        mkdir -p "${shaderCacheDir}" "${dxvkCacheDir}"
      '';
    };
  };

  users.groups.steam = lib.mkIf (has "steam") { };

  # Steam treats a library as read-only if any mount of that block device
  # is ro (/nix/store on the root disk). Overlay gives /steam a new device
  # id without FUSE. Shader cache stays on real ext4 under /home.
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
      "metacopy=on"
    ];
  };

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
    "d /var/lib/steam-library 0775 ${user} steam -"
    "d /var/lib/steam-library/steamapps 0775 ${user} steam -"
    "d /var/lib/steam-library/steamapps/common 0775 ${user} steam -"
    "d /var/lib/steam-library/steamapps/downloading 0775 ${user} steam -"
    "d /var/lib/steam-library/steamapps/temp 0775 ${user} steam -"
    "d /var/lib/steam-upper 0775 ${user} steam -"
    "d /var/lib/steam-work 0700 root root -"
    "d ${shaderCacheDir} 0755 ${user} users -"
    "d ${dxvkCacheDir} 0755 ${user} users -"
  ];

  environment.systemPackages = (map (name: packageMap.${name}) mapped) ++ [
    pkgs.dmidecode
    pkgs.lshw
    pkgs.bubblewrap
    pkgs.xdg-dbus-proxy
    (pkgs.writeShellScriptBin "wayland-box" ''
      exec ${scripts}/wayland-box.sh "$@"
    '')
    (pkgs.writeShellScriptBin "idea-ultimate" ''
      export IDEA_ULTIMATE_BIN=${lib.getExe pkgs.jetbrains.idea}
      exec ${scripts}/idea-ultimate.sh "$@"
    '')
  ];

  users.users = lib.mapAttrs (_: _: {
    extraGroups = lib.optional (has "docker") "docker" ++ lib.optional (has "steam") "steam";
  }) params.users;
}
