{
  config,
  lib,
  pkgs,
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

  auroraQsDir = "${config.home.homeDirectory}/config/home/dots/aurora-qs";
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
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/config/home/dots/scripts";
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
    source = ./dots/satty/config.toml;
    force = true;
  };

  home.file.".wall".source = ./dots/wallpapers;
  home.file.".wall".recursive = true;

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
      StartLimitBurst = 8;
      StartLimitIntervalSec = 60;
    };
    Service = {
      Type = "exec";
      # Hyprland also kicks this unit. Without --no-duplicate a second
      # process starts and draws a second bar on the same monitor.
      ExecStart = "${lib.getExe pkgs.quickshell} --no-duplicate";
      # Dock-launched apps inherit this cgroup. control-group would kill
      # Chrome/Cursor/games when the bar dies or reloads.
      KillMode = "process";
      Restart = "on-failure";
      RestartSec = 2;
      Slice = "session.slice";
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
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
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
    mkdir -p "$HOME/.local/state/aurora" "$HOME/.cache/aurora" "$HOME/.wall" "$HOME/Pictures/Screenshots" "$HOME/.local/state"

    if [ ! -f "$HOME/.local/state/monitor-brightness" ]; then
      echo 100 > "$HOME/.local/state/monitor-brightness"
    fi

    if [ ! -s "$HOME/.local/state/aurora/wallpaper" ] && [ -s "$HOME/.cache/aurora/current-wallpaper" ]; then
      cp -f "$HOME/.cache/aurora/current-wallpaper" "$HOME/.local/state/aurora/wallpaper"
    fi
    if [ ! -s "$HOME/.local/state/aurora/wallpaper" ] && [ -s "$HOME/.wall/.current.default" ]; then
      name="$(tr -d '[:space:]' < "$HOME/.wall/.current.default")"
      if [ -f "$HOME/.wall/$name" ]; then
        printf '%s\n' "$HOME/.wall/$name" > "$HOME/.local/state/aurora/wallpaper"
      fi
    fi
  '';

  home.packages = [
    brightnessctl
    pkgs.ddcutil
  ]
  ++ (with pkgs; [
    quickshell
    cava
    wtype
    satty
    awww
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
    libsForQt5.qt5ct
    libsForQt5.qtstyleplugin-kvantum
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
  ]);
}
