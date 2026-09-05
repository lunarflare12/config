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
      pkgs.hyprland
      pkgs.hyprsunset
    ];
    text = ''
      STATE_DIR="''${XDG_STATE_HOME:-$HOME/.local/state}"
      STATE="$STATE_DIR/monitor-brightness"
      mkdir -p "$STATE_DIR"

      current=100
      if [[ -f "$STATE" ]]; then
        current=$(tr -cd '0-9' < "$STATE" || true)
      fi
      [[ -z "$current" ]] && current=100

      clamp() {
        local v=$1
        if ! [[ "$v" =~ ^[0-9]+$ ]]; then
          v=$current
        fi
        if [ "$v" -lt 10 ]; then v=10; fi
        if [ "$v" -gt 100 ]; then v=100; fi
        printf '%s' "$v"
      }

      apply() {
        local v
        v=$(clamp "$1")
        hyprctl hyprsunset gamma "$v" >/dev/null 2>&1 || true
        printf '%s\n' "$v" > "$STATE"
        current=$v
      }

      machine=0
      action=""
      value=""
      for arg in "$@"; do
        case "$arg" in
          -m|--machine) machine=1 ;;
          set|info|-l|--list) action="$arg" ;;
          *) value="$arg" ;;
        esac
      done

      case "$action" in
        set)
          case "$value" in
            +*)
              n=''${value#+}
              n=''${n%"%"}
              apply $((current + n))
              ;;
            *%+)
              n=''${value%"%+"}
              apply $((current + n))
              ;;
            *%-)
              n=''${value%"%-"}
              apply $((current - n))
              ;;
            *%)
              n=''${value%"%"}
              apply "$n"
              ;;
            *)
              apply "$value"
              ;;
          esac
          ;;
      esac

      printf '%s\n' "$current" > "$STATE"
      if [[ "$machine" -eq 1 ]]; then
        echo "hypr,backlight,$current,''${current}%,100"
      fi
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

  quickshellConfig = pkgs.runCommand "aurora-quickshell-config" { } ''
    mkdir -p "$out"
    cp -r ${./dots/aurora-qs}/. "$out/"
    chmod -R u+w "$out"
    mkdir -p "$out/assets"
    cp ${emojiDatabase} "$out/assets/emoji.json"
    chmod -R u-w "$out"
  '';
in
{
  xdg.configFile."quickshell" = {
    source = quickshellConfig;
    force = true;
  };


  xdg.configFile."dunst/dunstrc".source = ./dots/dunst/dunstrc;
  xdg.configFile."dunst/themes/dark.conf".source = ./dots/dunst/themes/dark.conf;
  xdg.configFile."dunst/themes/light.conf".source = ./dots/dunst/themes/light.conf;

  xdg.configFile."mako".source = ./dots/mako;
  xdg.configFile."mako".recursive = true;
  xdg.configFile."mako".force = true;

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

  xdg.dataFile."dbus-1/services/org.freedesktop.Notifications.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.Notifications
    Exec=${pkgs.quickshell}/bin/qs
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

  systemd.user.services.quickshell = {
    Unit = {
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
      ExecStart = "${lib.getExe pkgs.quickshell}";
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
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      ExecStart = "${pkgs.awww}/bin/awww-daemon";
      ExecStartPost = "${pkgs.writeShellScript "awww-ready" ''
        export PATH="${lib.makeBinPath [
          pkgs.awww
          pkgs.coreutils
          pkgs.findutils
        ]}:$PATH"
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

  systemd.user.services.wallpaper = {
    Unit = {
      Description = "Set wallpaper";
      After = [
        "graphical-session.target"
        "awww.service"
      ];
      Wants = [ "awww.service" ];
      PartOf = [
        "graphical-session.target"
        "awww.service"
      ];
      BindsTo = [ "awww.service" ];
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
    mkdir -p "${config.xdg.configHome}/fuzzel" "${config.xdg.configHome}/dunst/dunstrc.d"
    mkdir -p "$HOME/.wall" "$HOME/Pictures/Screenshots" "$HOME/.cache/aurora"

    mkdir -p "$HOME/.local/state"
    if [ ! -f "$HOME/.local/state/monitor-brightness" ]; then
      echo 100 > "$HOME/.local/state/monitor-brightness"
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

  home.packages = [
    brightnessctl
  ]
  ++ (with pkgs; [
    quickshell
    kitty
    cava
    wtype
    satty
    flameshot
    awww
    fuzzel
    hyprsunset
    hyprpicker
    hyprshot
    hyprpolkitagent
    grim
    slurp
    wf-recorder
    cliphist
    wl-clipboard
    libnotify
    playerctl
    jq
    networkmanagerapplet
    pavucontrol
    libsForQt5.qt5ct
    kdePackages.qt6ct
    kdePackages.qtstyleplugin-kvantum
    python3Packages.evdev
  ]);
}
