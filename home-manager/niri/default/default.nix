{ config, lib, pkgs, wmConfig ? {
  output = "DP-4";
  mode = "2560x1080@200.000";
  scale = 1;
}, ... }:
let
  niriCfg = wmConfig;

  body0 = builtins.readFile ./config-body.kdl;
  pathEnv = lib.concatStringsSep ":" [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.local/state/nix/profiles/home-manager/home-path/bin"
    "/etc/profiles/per-user/${config.home.username}/bin"
    "/run/current-system/sw/bin"
  ];

  body1 = builtins.replaceStrings
    [ "@HOME@" "@PATH_ENV@" ]
    [ config.home.homeDirectory pathEnv ]
    body0;

  outputBlock = ''
    output "${niriCfg.output}" {
        mode "${niriCfg.mode}"
        scale ${builtins.toString niriCfg.scale}
    }

  '';

  niriConfigText = ''
    prefer-no-csd

  '' + outputBlock + body1;
in {
  xdg.configFile."niri/config.kdl" = {
    force = true;
    text = niriConfigText;
  };

  xdg.configFile."niri/theme.kdl".source = ./theme.kdl;

  home.packages = with pkgs; [
    awww
    cliphist
    wl-clipboard
    wl-clip-persist
    wtype
    fuzzel
    brightnessctl
    playerctl
    xwayland-satellite
  ];
}
