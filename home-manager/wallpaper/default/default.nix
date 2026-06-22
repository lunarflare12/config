{ config, lib, pkgs, ... }:
let
  assetsDir = ../../../assets/wallpapers;

  wallpapers = [
    "36.png"
    "aurora_borealis.png"
    "moments_before_desk.png"
    "wallhaven-yxx7j7_3840x2160.png"
  ];

  wallpaperFiles = lib.genAttrs wallpapers (
    name: {
      source = "${assetsDir}/${name}";
    }
  );
in {
  home.file = lib.mapAttrs' (
    name: value:
    lib.nameValuePair "Pictures/wallpapers/${name}" value
  ) wallpaperFiles;

  home.packages = [
    (pkgs.writeShellApplication {
      name = "swww-restore";
      runtimeInputs = [ pkgs.awww ];
      text = builtins.readFile ./scripts/swww-restore.sh;
    })
    (pkgs.writeShellApplication {
      name = "wallpaper-picker";
      runtimeInputs = [
        pkgs.awww
        pkgs.fuzzel
        pkgs.libnotify
      ];
      text = builtins.readFile ./scripts/wallpaper-picker.sh;
    })
  ];
}
