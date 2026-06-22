{ pkgs, ... }:
{
  home.packages = [ pkgs.swaynotificationcenter ];

  xdg.configFile."swaync/config.json" = {
    source = ./config.json;
    force = true;
  };
  xdg.configFile."swaync/style.css" = {
    source = ./style.css;
    force = true;
  };
  xdg.configFile."swaync/icons" = {
    source = ./icons;
    force = true;
  };
}
