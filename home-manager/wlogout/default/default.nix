{ pkgs, lib, ... }:
let
  niri = lib.getExe pkgs.niri;
  systemctl = lib.getExe' pkgs.systemd "systemctl";

  layout = builtins.readFile ./layout;
  layoutText = builtins.replaceStrings
    [ "@NIRI@" "@SYSTEMCTL@" ]
    [ niri systemctl ]
    layout;
in
{
  home.packages = [ pkgs.wlogout ];

  xdg.configFile."wlogout/icons".source = "${pkgs.wlogout}/share/wlogout/icons";
  xdg.configFile."wlogout/layout".text = layoutText;
  xdg.configFile."wlogout/style.css".source = ./style.css;
}
