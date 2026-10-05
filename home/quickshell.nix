{
  config,
  lib,
  pkgs,
  params,
  ...
}:

let
  emojiSource = pkgs.fetchurl {
    url = "https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt";
    hash = "sha256-HYqUT4jXlS9+98UWf+88Z5lbyuJFQ5SXECMbA6IBrNo=";
  };

  emojiDatabase =
    pkgs.runCommand "aurora-emoji-database"
      {
        nativeBuildInputs = [ pkgs.aurora-helpers ];
      }
      ''
        mkdir -p "$out"
        ${pkgs.aurora-helpers}/bin/aurora emoji build ${emojiSource} "$out/emoji.json"
      '';

  repoRoot = "${config.home.homeDirectory}/${params.repo}";
  auroraQsDir = "${repoRoot}/home/dots/aurora-qs";
in
{
  # Flakes omit untracked QML. Point ~/.config/quickshell at the git tree so
  # reboot, qs ipc, and live edits all use the same files.
  xdg.configFile."quickshell" = {
    source = config.lib.file.mkOutOfStoreSymlink auroraQsDir;
    force = true;
  };

  xdg.configFile."Kvantum".source = ./dots/kvantum;
  xdg.configFile."Kvantum".recursive = true;

  xdg.configFile."fastfetch".source = ./dots/fastfetch;
  xdg.configFile."fastfetch".recursive = true;

  # Drop legacy ~/.config/scripts symlink tree (everything is aurora + HM shims).
  home.activation.replaceScriptsStoreDir = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    scripts="${config.xdg.configHome}/scripts"
    if [ -e "$scripts" ]; then
      rm -rf "$scripts"
    fi
    qs="${config.xdg.configHome}/quickshell"
    if [ -d "$qs" ] && [ ! -L "$qs" ]; then
      backup="$qs.store-dir.bak"
      rm -rf "$backup"
      mv "$qs" "$backup"
    fi
  '';

  xdg.configFile."satty/config.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/dots/satty/config.toml";
    force = true;
  };

  xdg.dataFile."icons/hicolor/512x512/apps/keymapp.png" = {
    source = ./dots/aurora-qs/assets/keymapp.png;
    force = true;
  };

  xdg.dataFile."dbus-1/services/org.freedesktop.Notifications.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.Notifications
    Exec=${pkgs.systemd}/bin/systemctl --user start quickshell.service
    SystemdService=quickshell.service
  '';

  dconf.settings = {
    "org/gnome/nm-applet" = {
      disable-connected-notifications = true;
      disable-disconnected-notifications = true;
      disable-vpn-notifications = true;
      suppress-wireless-networks-available = true;
    };
  };

  xdg.configFile."autostart/nm-applet.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';

  systemd.user.services.quickshell = {
    Unit = {
      # home-manager must not restart this unit: NVIDIA SIGTRAPs Electron.
      X-SwitchMethod = "keep-old";
      Description = "Quickshell desktop shell and notification daemon";
      After = [
        "graphical-session.target"
        "dbus.socket"
      ];
      PartOf = [ "graphical-session.target" ];
      Requires = [ "dbus.socket" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
      StartLimitBurst = 20;
      StartLimitIntervalSec = 120;
    };
    Service = {
      Type = "exec";
      # Hyprland also kicks this unit. Without --no-duplicate a second
      # process starts and draws a second bar on the same monitor.
      ExecStart = "${lib.getExe pkgs.quickshell} --no-duplicate";
      # Drop leftover helpers from a previous crash (KillMode=process keeps them).
      ExecStartPre = "-${lib.getExe pkgs.aurora-helpers} helpers kill-qs";
      # Launched apps inherit this cgroup. control-group would kill
      # Chrome/Cursor/games when the bar dies or reloads. AppsService uses
      # systemd-run --scope for real launches; helpers are cleaned above.
      KillMode = "process";
      # Always bring the panel back — games/scripts and NVIDIA quirks can
      # kill qs; on-failure alone leaves the desktop barless after SIGKILL.
      Restart = "always";
      RestartSec = 1;
      Slice = "session.slice";
      # qs is a layer-shell, not a portal app. The leftover helper
      # processes from KillMode=process make Qt re-register the same id.
      Environment = [
        "QT_QPA_PLATFORM=wayland"
        "QT_NO_XDG_DESKTOP_PORTAL=1"
        # Integer-scale monitors: do not let Qt invent a fractional factor
        # that rasterizes the shell soft and then upscales it.
        "QT_AUTO_SCREEN_SCALE_FACTOR=0"
        "QT_ENABLE_HIGHDPI_SCALING=1"
        "QT_SCALE_FACTOR_ROUNDING_POLICY=Round"
        "QML_IMPORT_PATH=${pkgs.qt6.qtmultimedia}/lib/qt-6/qml"
        # Prepend multimedia plugins; keep qtwayland/qtdeclarative from the qs wrap.
        "QT_PLUGIN_PATH=${pkgs.qt6.qtmultimedia}/lib/qt-6/plugins:${pkgs.qt6.qtwayland}/lib/qt-6/plugins:${pkgs.qt6.qtdeclarative}/lib/qt-6/plugins:${pkgs.qt6.qtsvg}/lib/qt-6/plugins"
        "QT_MEDIA_BACKEND=ffmpeg"
      ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.hyprsunset = {
    Unit = {
      Description = "Hyprland display gamma";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.hyprsunset} --identity";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.awww = {
    Unit = {
      Description = "Wallpaper daemon";
      After = [
        "graphical-session.target"
        "wayland-wm@hyprland.desktop.service"
      ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.aurora-helpers} wallpaper daemon";
      ExecStartPost = "${pkgs.writeShellScript "awww-ready" ''
        export PATH="${
          lib.makeBinPath [
            pkgs.awww
            pkgs.coreutils
            pkgs.findutils
          ]
        }:$PATH"
        for i in $(seq 1 50); do
          ${pkgs.awww}/bin/awww query >/dev/null 2>&1 && break
          sleep 0.1
        done
        exec ${lib.getExe pkgs.aurora-helpers} wallpaper load
      ''}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.auroraState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "${auroraQsDir}/assets"
    ln -sfn ${emojiDatabase}/emoji.json "${auroraQsDir}/assets/emoji.json"
    mkdir -p "$HOME/.local/state/aurora" "$HOME/.cache/aurora" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots" "$HOME/.local/state"
    rm -rf "$HOME/.local/state/aurora/bin"

    # Launchpad/dock pins — keep out of HM-managed ~/.config/aurora.
    state_layout="$HOME/.local/state/aurora/app-layout.json"
    state_backup="$HOME/.local/state/aurora/app-layout.backup.json"
    config_layout="$HOME/.config/aurora/app-layout.json"
    if [ ! -s "$state_layout" ]; then
      if [ -s "$config_layout" ]; then
        cp -f "$config_layout" "$state_layout"
      elif [ -s "$HOME/.cache/aurora/app-layout.json" ]; then
        cp -f "$HOME/.cache/aurora/app-layout.json" "$state_layout"
      fi
    fi
    if [ -s "$state_layout" ] && [ ! -s "$state_backup" ]; then
      cp -f "$state_layout" "$state_backup"
    fi
    # Prefer the richest layout (folders win). Flat alpha rewrites must not
    # beat the user's foldered ~/.config copy or an older backup.
    if [ -s "$state_layout" ]; then
      if [ -s "$config_layout" ]; then
        ${pkgs.aurora-helpers}/bin/aurora state prefer-layout-backup "$state_layout" "$config_layout" || true
      fi
      if [ -s "$state_backup" ]; then
        ${pkgs.aurora-helpers}/bin/aurora state prefer-layout-backup "$state_layout" "$state_backup" || true
        ${pkgs.aurora-helpers}/bin/aurora state prefer-layout-backup "$state_backup" "$state_layout" || true
      fi
    fi

    if [ ! -f "$HOME/.local/state/monitor-brightness" ]; then
      echo 100 > "$HOME/.local/state/monitor-brightness"
    fi

    if [ ! -s "$HOME/.local/state/aurora/wallpaper" ] && [ -s "$HOME/.cache/aurora/current-wallpaper" ]; then
      cp -f "$HOME/.cache/aurora/current-wallpaper" "$HOME/.local/state/aurora/wallpaper"
    fi
    if [ ! -s "$HOME/.local/state/aurora/wallpaper" ]; then
      first="$(find -L "$HOME/Pictures/Wallpapers" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) ! -name '.*' 2>/dev/null | sort | head -n 1 || true)"
      if [ -n "$first" ]; then
        printf '%s\n' "$first" > "$HOME/.local/state/aurora/wallpaper"
      fi
    fi
  '';

  home.packages = [
    pkgs.aurora-helpers
    pkgs.ddcutil
  ]
  ++ (with pkgs; [
    quickshell
    # DesktopService needs `gio trash` on qs PATH.
    glib.bin
    cava
    wtype
    satty
    awww
    mpvpaper
    hyprsunset
    hyprpicker
    hyprpolkitagent
    grim
    slurp
    wf-recorder
    cliphist
    wl-clipboard
    libnotify
    playerctl
    jq
    pavucontrol
    networkmanagerapplet
    libsForQt5.qt5ct
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
  ]);
}
