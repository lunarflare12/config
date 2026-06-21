{ pkgs, ... }:
{
  home.packages = with pkgs; [
    waybar
    swayosd
    playerctl
    sway-audio-idle-inhibit
    udisks
    btop
    jq
    curl
    iproute2
    wireplumber
    pavucontrol
  ];

  xdg.configFile."waybar/config.json".source = ./config.json;
  xdg.configFile."waybar/config".source = ./config.json;
  xdg.configFile."waybar/style.css".source = ./style.css;
  xdg.configFile."waybar/colors-waybar.css".source = ./colors-waybar.css;

  xdg.configFile."waybar/scripts/volume.sh" = {
    source = ./scripts/volume.sh;
    executable = true;
  };
  xdg.configFile."waybar/scripts/brightness.sh" = {
    source = ./scripts/brightness.sh;
    executable = true;
  };
  xdg.configFile."waybar/scripts/wallpaper-random.sh" = {
    source = ./scripts/wallpaper-random.sh;
    executable = true;
  };
  xdg.configFile."waybar/scripts/eject-usb.sh" = {
    source = ./scripts/eject-usb.sh;
    executable = true;
  };
  xdg.configFile."waybar/scripts/network.sh" = {
    source = ./scripts/network.sh;
    executable = true;
  };
}
