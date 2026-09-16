{
  config,
  pkgs,
  params,
  ...
}:

{
  home.stateVersion = params.stateVersion;

  home.pointerCursor = {
    enable = true;
    name = "macOS";
    package = pkgs.apple-cursor;
    size = params.cursorSize;
    gtk.enable = true;
    x11.enable = true;
  };

  home.sessionVariables = {
    TERMINAL = params.terminal;
    BROWSER = params.browser;
    EDITOR = "nvim";
    HYPRSHOT_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
    VAGRANT_DEFAULT_PROVIDER = "libvirt";
    LIBVIRT_DEFAULT_URI = "qemu:///system";
  };

  xdg.enable = true;
  xdg.mimeApps.enable = true;
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps.defaultApplications = {
    "text/html" = "${params.browser}.desktop";
    "x-scheme-handler/http" = "${params.browser}.desktop";
    "x-scheme-handler/https" = "${params.browser}.desktop";
    "application/pdf" = "org.pwmt.zathura.desktop";
    "application/epub+zip" = "org.pwmt.zathura.desktop";
  };

  imports = [
    ./hyprland.nix
    ./hyprlock.nix
    ./kitty.nix
    ./theme.nix
    ./shell.nix
    ./apps.nix
    ./quickshell.nix
    ./obs.nix
  ];
}
