{
  config,
  pkgs,
  params,
  ...
}:

{
  programs.hyprlock.enable = true;

  xdg.configFile."hypr/hyprlock.conf".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${params.repo}/home/dots/hypr/hyprlock.conf";
  xdg.configFile."hypr/hypridle.conf".source = ./dots/hypr/hypridle.conf;

  xdg.configFile."hyprlock/images/avatar.jpg".source = ../modules/sddm/glyph/assets/images/avatar.jpg;
  xdg.configFile."hyprlock/images/background.jpg".source =
    ../modules/sddm/glyph/assets/images/background.jpg;

  home.file.".local/share/fonts/Ndot-57-Aligned.ttf".source =
    ../modules/sddm/glyph/assets/fonts/Ndot-57-Aligned.ttf;

  home.packages = [ pkgs.hypridle ];
}
