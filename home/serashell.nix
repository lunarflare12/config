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

  systemd.user.services.awww = {
    Unit = {
      Description = "Wallpaper daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      ExecStartPost = "${pkgs.writeShellScript "awww-ready" ''
        for i in $(seq 1 50); do
          ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && exit 0
          sleep 0.1
        done
        exit 0
      ''}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Set wallpaper";
      After = [
        "graphical-session.target"
        "awww.service"
      ];
      Wants = [ "awww.service" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.writeShellScript "load-wallpaper" ''
        export PATH="${lib.makeBinPath [
          pkgs.awww
          pkgs.coreutils
          pkgs.findutils
        ]}:$PATH"
        exec ${config.home.homeDirectory}/.config/scripts/load-wallpaper.sh
      ''}";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.serashellState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${config.xdg.configHome}/quickshell" "${config.xdg.configHome}/fuzzel" "${config.xdg.configHome}/dunst/dunstrc.d"
    mkdir -p "$HOME/.wall" "$HOME/Pictures/Screenshots"

    if [ ! -e "${config.xdg.configHome}/quickshell/theme-mode" ]; then
      echo dark > "${config.xdg.configHome}/quickshell/theme-mode"
    fi

    settings="${config.xdg.configHome}/quickshell/pill-settings"
    default="${config.xdg.configHome}/quickshell/pill-settings.default"
    if [ -L "$settings" ] || [ ! -f "$settings" ]; then
      rm -f "$settings"
      cp -L --remove-destination "$default" "$settings"
    elif [ ! -w "$settings" ]; then
      tmp="$(mktemp)"
      cp -L "$settings" "$tmp"
      rm -f "$settings"
      mv "$tmp" "$settings"
    fi
    chmod u+w "$settings"
    sed -i 's/^showBattery=.*/showBattery=${if params.hardware.battery or false then "true" else "false"}/' "$settings"
    if grep -q '^showBluetooth=' "$settings"; then
      sed -i 's/^showBluetooth=.*/showBluetooth=${if params.hardware.bluetooth or false then "true" else "false"}/' "$settings"
    else
      printf '\nshowBluetooth=${if params.hardware.bluetooth or false then "true" else "false"}\n' >> "$settings"
    fi

    if [ ! -e "${config.xdg.configHome}/fuzzel/theme.ini" ]; then
      ln -sfn "${config.xdg.configHome}/fuzzel/themes/dark.ini" "${config.xdg.configHome}/fuzzel/theme.ini"
    fi
    if [ ! -L "${config.xdg.configHome}/dunst/dunstrc.d/99-theme.conf" ] && [ ! -e "${config.xdg.configHome}/dunst/dunstrc.d/99-theme.conf" ]; then
      ln -sfn "${config.xdg.configHome}/dunst/themes/dark.conf" "${config.xdg.configHome}/dunst/dunstrc.d/99-theme.conf"
    fi
    if [ ! -s "$HOME/.wall/.current" ] && [ -s "$HOME/.wall/.current.default" ]; then
      cp -L "$HOME/.wall/.current.default" "$HOME/.wall/.current"
    fi
  '';

  home.packages = with pkgs; [
    quickshell
    awww
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
