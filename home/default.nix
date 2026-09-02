{ config, params, ... }:

{
  home.stateVersion = params.stateVersion;

  home.sessionVariables = {
    TERMINAL = params.terminal;
    BROWSER = params.browser;
    EDITOR = "nvim";
    HYPRSHOT_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
  };

  xdg.enable = true;
  xdg.mimeApps.enable = true;
  xdg.configFile."mimeapps.list".force = true;
  xdg.mimeApps.defaultApplications = {
    "text/html" = "${params.browser}.desktop";
    "x-scheme-handler/http" = "${params.browser}.desktop";
    "x-scheme-handler/https" = "${params.browser}.desktop";
  };

  imports = [
    ./hyprland.nix
    ./alacritty.nix
    ./shell.nix
    ./apps.nix
    ./serashell.nix
  ];
}
