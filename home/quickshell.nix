{
  config,
  lib,
  pkgs,
  params,
  ...
}:

let
  brightnessctl = pkgs.writeShellApplication {
    name = "brightnessctl";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.python3
      pkgs.hyprland
      pkgs.ddcutil
    ];
    text = ''
      exec python3 ${./dots/scripts/monitor-brightness} "$@"
    '';
  };

  emojiSource = pkgs.fetchurl {
    url = "https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt";
    hash = "sha256-HYqUT4jXlS9+98UWf+88Z5lbyuJFQ5SXECMbA6IBrNo=";
  };

  emojiDatabase = pkgs.runCommand "aurora-emoji-database" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 - "${emojiSource}" "$out" <<'PY'
    import json
    import re
    import sys

    source = sys.argv[1]
    output = sys.argv[2]
    items = []
    group = ""
    subgroup = ""

    with open(source, encoding="utf-8") as f:
        for line in f:
            line = line.rstrip()
            if line.startswith("# group:"):
                group = line.split(":", 1)[1].strip()
                continue
            if line.startswith("# subgroup:"):
                subgroup = line.split(":", 1)[1].strip()
                continue
            if not line or line.startswith("#"):
                continue
            match = re.match(
                r"^([0-9A-F ]+);\s+fully-qualified\s+#\s+(\S+)\s+(.+)$",
                line,
            )
            if not match:
                continue
            emoji = "".join(chr(int(cp, 16)) for cp in match.group(1).split())
            items.append({
                "emoji": emoji,
                "name": match.group(3).strip().lower(),
                "group": group.lower(),
                "subgroup": subgroup.lower(),
            })

    with open(output, "w", encoding="utf-8") as f:
        json.dump(items, f, ensure_ascii=False, separators=(",", ":"))
    PY
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

  xdg.configFile."scripts" = {
    source = config.lib.file.mkOutOfStoreSymlink "${repoRoot}/home/dots/scripts";
    force = true;
  };

  # Last generation wrote a directory of store copies. Move it so this
  # generation can place the git-tree symlink.
  home.activation.replaceScriptsStoreDir = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    scripts="${config.xdg.configHome}/scripts"
    if [ -d "$scripts" ] && [ ! -L "$scripts" ]; then
      backup="$scripts.store-dir.bak"
      rm -rf "$backup"
      mv "$scripts" "$backup"
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

  systemd.user.services.aurora-notify-proxy = {
    Unit = {
      Description = "Filtered D-Bus proxy so boxed apps share Aurora notifications";
      After = [ "dbus.socket" ];
      Requires = [ "dbus.socket" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.xdg-dbus-proxy}/bin/xdg-dbus-proxy unix:path=%t/bus %t/aurora-notify.sock --filter --talk=org.freedesktop.Notifications";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

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
      StartLimitBurst = 8;
      StartLimitIntervalSec = 60;
    };
    Service = {
      Type = "exec";
      # Hyprland also kicks this unit. Without --no-duplicate a second
      # process starts and draws a second bar on the same monitor.
      ExecStart = "${lib.getExe pkgs.quickshell} --no-duplicate";
      # Drop leftover helpers from a previous crash (KillMode=process keeps them).
      ExecStartPre = "-${config.home.homeDirectory}/.config/scripts/aurora-kill-qs-helpers.sh";
      # Dock-launched apps inherit this cgroup. control-group would kill
      # Chrome/Cursor/games when the bar dies or reloads. AppsService uses
      # systemd-run --scope for real launches; helpers are cleaned above.
      KillMode = "process";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
      # qs is a layer-shell, not a portal app. The leftover helper
      # processes from KillMode=process make Qt re-register the same id.
      Environment = [
        "QT_QPA_PLATFORM=wayland"
        "QT_NO_XDG_DESKTOP_PORTAL=1"
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
      ExecStart = "${config.home.homeDirectory}/.config/scripts/wallpaper-daemon.sh";
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
        exec ${config.home.homeDirectory}/.config/scripts/load-wallpaper.sh
      ''}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  home.activation.auroraState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        mkdir -p "${auroraQsDir}/assets"
        ln -sfn ${emojiDatabase} "${auroraQsDir}/assets/emoji.json"
        mkdir -p "$HOME/.local/state/aurora" "$HOME/.cache/aurora" "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots" "$HOME/.local/state"

        # Launchpad/dock pins — keep out of HM-managed ~/.config/aurora.
        state_layout="$HOME/.local/state/aurora/app-layout.json"
        state_backup="$HOME/.local/state/aurora/app-layout.backup.json"
        if [ ! -s "$state_layout" ]; then
          if [ -s "$HOME/.config/aurora/app-layout.json" ]; then
            cp -f "$HOME/.config/aurora/app-layout.json" "$state_layout"
          elif [ -s "$HOME/.cache/aurora/app-layout.json" ]; then
            cp -f "$HOME/.cache/aurora/app-layout.json" "$state_layout"
          fi
        fi
        if [ -s "$state_layout" ] && [ ! -s "$state_backup" ]; then
          cp -f "$state_layout" "$state_backup"
        fi
        # If backup is richer (more folders), prefer it — sync races used to wipe pins.
        if [ -s "$state_backup" ] && [ -s "$state_layout" ]; then
          python3 - "$state_layout" "$state_backup" <<'PY' || true
    import json, sys
    def score(p):
        try:
            d = json.load(open(p))
        except Exception:
            return (-1, -1)
        lp = d.get("launchpad") or []
        folders = sum(1 for x in lp if isinstance(x, dict))
        return (folders, len(lp))
    layout, backup = sys.argv[1], sys.argv[2]
    if score(backup) > score(layout):
        open(layout, "w").write(open(backup).read())
    PY
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
    brightnessctl
    pkgs.ddcutil
  ]
  ++ (with pkgs; [
    quickshell
    # Dock trash / DesktopService need `gio trash` on qs PATH.
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
