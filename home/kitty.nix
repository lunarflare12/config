{
  config,
  params,
  ...
}:

let
  kittyIcon = ./dots/aurora-qs/assets/kitty.png;
  kittyConf = "${config.home.homeDirectory}/${params.repo}/home/kitty/config/kitty.conf";
in
{
  programs.kitty.enable = true;

  xdg.configFile."kitty/kitty.conf" = {
    source = config.lib.file.mkOutOfStoreSymlink kittyConf;
    force = true;
  };

  # Icon=kitty resolves through WhiteSur to the stock cat face. Point the
  # desktop file at the Aurora asset and drop it into hicolor under our name.
  xdg.desktopEntries.kitty = {
    name = "kitty";
    genericName = "Terminal emulator";
    comment = "A fast, feature-rich, GPU based terminal";
    exec = "kitty";
    icon = "${kittyIcon}";
    terminal = false;
    categories = [
      "System"
      "TerminalEmulator"
    ];
    startupNotify = true;
    settings.StartupWMClass = "kitty";
  };

  xdg.dataFile."icons/hicolor/256x256/apps/kitty.png" = {
    source = kittyIcon;
    force = true;
  };
}
