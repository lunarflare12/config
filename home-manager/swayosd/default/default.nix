{ pkgs, ... }:
{
  services.swayosd = {
    enable = true;
    topMargin = 0.85;
    stylePath = "${pkgs.swayosd}/etc/xdg/swayosd/style.css";
  };
}
