{
  config,
  lib,
  pkgs,
  params,
  ...
}:

{
  xdg.configFile."quickshell".source = ./dots/quickshell;
  xdg.configFile."quickshell".recursive = true;

  xdg.configFile."dunst/dunstrc".source = ./dots/dunst/dunstrc;
  xdg.configFile."dunst/themes/dark.conf".source = ./dots/dunst/themes/dark.conf;
  xdg.configFile."dunst/themes/light.conf".source = ./dots/dunst/themes/light.conf;

  xdg.configFile."mako".source = ./dots/mako;
  xdg.configFile."mako".recursive = true;

  xdg.configFile."Kvantum".source = ./dots/kvantum;
  xdg.configFile."Kvantum".recursive = true;

  xdg.configFile."fastfetch".source = ./dots/fastfetch;
  xdg.configFile."fastfetch".recursive = true;

  xdg.configFile."fuzzel/themes".source = ./dots/fuzzel/themes;
  xdg.configFile."fuzzel/fuzzel_theme.ini".source = ./dots/fuzzel/fuzzel_theme.ini;
  xdg.configFile."fuzzel/fuzzel.ini".text = ''
    include="${config.xdg.configHome}/fuzzel/fuzzel_theme.ini"
    include="${config.xdg.configHome}/fuzzel/theme.ini"
    font=JetBrainsMono Nerd Font
    terminal=${params.terminal}
    prompt="->  "
    layer=overlay

    [border]
    radius=17
    width=1

    [dmenu]
    exit-immediately-if-empty=yes
  '';

  xdg.configFile."scripts".source = ./dots/scripts;
  xdg.configFile."scripts".recursive = true;

  home.file.".wall".source = ./dots/wallpapers;
  home.file.".wall".recursive = true;

  home.activation.serashellState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.configHome}/quickshell" "${config.xdg.configHome}/fuzzel" "${config.xdg.configHome}/dunst/dunstrc.d"
    if [ ! -e "${config.xdg.configHome}/quickshell/theme-mode" ]; then
      echo dark > "${config.xdg.configHome}/quickshell/theme-mode"
    fi
    if [ ! -e "${config.xdg.configHome}/quickshell/pill-settings" ]; then
      cp "${config.xdg.configHome}/quickshell/pill-settings.default" "${config.xdg.configHome}/quickshell/pill-settings"
    fi
    if [ ! -e "${config.xdg.configHome}/fuzzel/theme.ini" ]; then
      ln -sfn "${config.xdg.configHome}/fuzzel/themes/dark.ini" "${config.xdg.configHome}/fuzzel/theme.ini"
    fi
    if [ ! -L "${config.xdg.configHome}/dunst/dunstrc.d/99-theme.conf" ] && [ ! -e "${config.xdg.configHome}/dunst/dunstrc.d/99-theme.conf" ]; then
      ln -sfn "${config.xdg.configHome}/dunst/themes/dark.conf" "${config.xdg.configHome}/dunst/dunstrc.d/99-theme.conf"
    fi
    mkdir -p "$HOME/.wall" "$HOME/Pictures/Screenshots"
    if [ ! -s "$HOME/.wall/.current" ] && [ -s "$HOME/.wall/.current.default" ]; then
      cp "$HOME/.wall/.current.default" "$HOME/.wall/.current"
    fi
  '';

  home.packages = with pkgs; [
    quickshell
    swww
    dunst
    fuzzel
    hyprpicker
    hyprshot
    hyprlock
    hypridle
    hyprpolkitagent
    grim
    slurp
    wf-recorder
    cliphist
    wl-clipboard
    libnotify
    playerctl
    brightnessctl
    jq
    networkmanagerapplet
    pavucontrol
    libsForQt5.qt5ct
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    python3Packages.evdev
  ];
}
