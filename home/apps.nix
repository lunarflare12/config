{
  config,
  lib,
  pkgs,
  params,
  inputs,
  space,
  ...
}:

let
  inherit (space) mkSpaces;
  scripts = "${config.home.homeDirectory}/.config/scripts";
  zenBrowser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
  spiceSpotify = config.programs.spicetify.spicedSpotify;
  spiceXpui = "${spiceSpotify}/share/spotify/Apps/xpui";
  chromeMime = [
    "application/pdf"
    "text/html"
    "text/xml"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ];
  chromeEntry = {
    name = "Chrome DD";
    genericName = "Web Browser";
    exec = "${scripts}/google-chrome.sh %U";
    icon = "google-chrome";
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = chromeMime;
    startupNotify = true;
    settings.StartupWMClass = "chrome-dd";
  };
  ideMime = [
    "application/x-code-workspace"
    "text/plain"
    "inode/directory"
  ];

  # Thin PATH shims that keep calling the git-tree scripts (compose + store
  # pins live there). Dark theme is injected by those scripts via space-env.
  shim =
    name: script:
    (pkgs.writeShellApplication {
      inherit name;
      text = ''exec ${scripts}/${script} "$@"'';
    }).overrideAttrs
      (old: {
        meta = (old.meta or { }) // {
          # Beat leftover vendor bins if a container pin still leaks into the profile.
          priority = 0;
        };
      });

  spaces = mkSpaces {
    discord = {
      kind = "host";
      # Official discord-1.0.155 SIGSEGV / exits on this host; Vesktop is the
      # working Discord client (window class: vesktop).
      package = pkgs.vesktop;
      platform = "wayland";
      forceDark = true;
      flags = [ ];
    };
    cursor = {
      kind = "host";
      package = pkgs.code-cursor;
      platform = "wayland";
      forceDark = true;
      env = {
        GTK_USE_PORTAL = "1";
      };
    };
    # startOnly containers: compose already carries dark x-env + theme mounts.
    spotify = {
      kind = "container";
      startOnly = true;
    };
    idea-ultimate = {
      kind = "container";
      service = "idea";
      startOnly = true;
    };
    telegram-2 = {
      kind = "container";
      compose = "containers/telegram/compose.yml";
      startOnly = true;
    };
  };

  inherit (spaces) discord cursor;
in
{
  programs.zathura = {
    enable = true;
    options = {
      selection-clipboard = "clipboard";
      adjust-open = "best-fit";
      default-bg = "#1e1e2e";
      default-fg = "#cdd6f4";
      recolor = true;
      recolor-keephue = true;
      recolor-darkcolor = "#cdd6f4";
      recolor-lightcolor = "#1e1e2e";
      statusbar-bg = "#181825";
      statusbar-fg = "#cdd6f4";
      inputbar-bg = "#181825";
      inputbar-fg = "#cdd6f4";
      notification-bg = "#181825";
      notification-fg = "#cdd6f4";
      highlight-color = "#f9e2af";
      highlight-active-color = "#89b4fa";
    };
  };

  # Shared dark-theme exports + `space_docker_env` for every launcher script.
  xdg.configFile."aurora/space-env.sh" = {
    text = space.spaceEnvSh;
    force = true;
  };

  # Theme name `google-chrome` after the host Chrome package left PATH.
  xdg.dataFile."icons/hicolor/256x256/apps/google-chrome.png" = {
    source = ./dots/aurora-qs/assets/google-chrome.png;
    force = true;
  };

  home.sessionPath = [ scripts ];

  home.packages = [
    pkgs.aurora-helpers
    pkgs.xrandr
    spaces.discord.package
    spaces.cursor.package
    spaces.spotify.package
    spaces.idea-ultimate.package
    spaces.telegram-2.package
    (shim "google-chrome" "google-chrome.sh")
    (shim "chrome-az" "chrome-az.sh")
    (shim "chrome-hika" "chrome-hika.sh")
    (shim "chrome-sciencesoft" "chrome-sciencesoft.sh")
    (shim "firefox" "firefox.sh")
    (shim "zen" "zen.sh")
    (shim "telegram-1" "telegram-1.sh")
    (shim "telegram" "telegram-1.sh")
    (shim "steam" "steam.sh")
    (shim "terraria" "terraria.sh")
    (shim "albion" "albion.sh")
    (shim "alien-shooter" "alien-shooter.sh")
    (shim "code" "code.sh")
    (shim "obsidian" "obsidian.sh")
    (shim "openlens" "openlens.sh")
    (shim "libreoffice" "libreoffice.sh")
    (shim "soffice" "libreoffice.sh")
    (pkgs.writeShellApplication {
      name = "wayland-box";
      text = ''exec ${./dots/scripts/wayland-box.sh} "$@"'';
    })
  ];

  # Keep store paths for containerized apps without installing their .desktop files.
  # Steam FHS is pinned via /etc/aurora/steam-bin (modules/steam.nix), not here.
  home.file.".local/share/aurora/container-store-refs".text = ''
    ${pkgs.google-chrome}
    ${pkgs.firefox}
    ${zenBrowser}
    ${pkgs.jetbrains.idea}
    ${pkgs.vscode}
    ${pkgs.obsidian}
    ${pkgs.openlens}
    ${pkgs.libreoffice}
    ${spiceSpotify}
    ${pkgs.openlens.extracted}
    ${pkgs.socat}
  '';

  # Compose interpolates these so a rebuild cannot leave stale /nix/store command paths.
  home.file."containers/apps/.env" = {
    text = ''
      CHROME_BIN=${pkgs.google-chrome}/bin/google-chrome-stable
      FIREFOX_BIN=${pkgs.firefox}/bin/firefox
      ZEN_BIN=${zenBrowser}/bin/zen
      IDEA_BIN=${pkgs.jetbrains.idea}/bin/idea
      SPOTIFY_BIN=${lib.getExe spiceSpotify}
      SPOTIFY_XPUI=${spiceXpui}
      OBSIDIAN_BIN=${pkgs.obsidian}/bin/obsidian
      LIBREOFFICE_BIN=${pkgs.libreoffice}/bin/soffice
      VSCODE_BIN=${pkgs.vscode}/bin/code
      VSCODE_ELECTRON=${pkgs.vscode}/lib/vscode/code
      OPENLENS_APP=${pkgs.openlens.extracted}
      SOCAT_BIN=${pkgs.socat}/bin/socat
    '';
    force = true;
  };

  home.file."containers/apps/launch-vscode.sh" = {
    executable = true;
    force = true;
    text = ''
      #!/bin/bash
      set -euo pipefail
      wrapper=${pkgs.vscode}/bin/code
      electron=${pkgs.vscode}/lib/vscode/code
      eval "$(sed '/^exec /d' "$wrapper")"
      unset ELECTRON_RUN_AS_NODE
      unset DISPLAY
      exec "$electron" \
        --ozone-platform=wayland \
        --force-dark-mode \
        --no-sandbox \
        --disable-setuid-sandbox \
        --user-data-dir=/home/app/.config/Code \
        "$@"
    '';
  };

  home.file."containers/apps/launch-openlens.sh" = {
    executable = true;
    force = true;
    text = ''
      #!/bin/sh
      set -eu
      app=${pkgs.openlens.extracted}
      export ICU_DATA="$app"
      unset DISPLAY
      cd "$app"
      exec "$app/open-lens" \
        --ozone-platform=wayland \
        --force-dark-mode \
        --no-sandbox \
        --disable-setuid-sandbox \
        "$@"
    '';
  };

  xdg.desktopEntries = {
    google-chrome = chromeEntry;
    "com.google.Chrome" = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    steam = {
      name = "Steam";
      exec = "${scripts}/steam.sh %U";
      icon = "steam";
      categories = [ "Game" ];
      mimeType = [
        "x-scheme-handler/steam"
        "x-scheme-handler/steamlink"
      ];
      terminal = false;
    };
    "albion-online" = {
      name = "Albion Online";
      exec = "${scripts}/albion.sh";
      icon = "steam_icon_761890";
      categories = [ "Game" ];
      terminal = false;
      settings.StartupWMClass = "steam_app_761890";
    };
    terraria = {
      name = "Terraria";
      exec = "${scripts}/terraria.sh";
      icon = "steam_icon_105600";
      categories = [ "Game" ];
      terminal = false;
      settings.StartupWMClass = "steam_app_105600";
    };
    alien-shooter = {
      name = "Alien Shooter";
      exec = "${scripts}/alien-shooter.sh";
      icon = "steam_icon_33100";
      categories = [ "Game" ];
      terminal = false;
      settings.StartupWMClass = "steam_app_33100";
    };
    discord = {
      name = "Discord";
      exec = "${scripts}/discord.sh";
      icon = "discord";
      categories = [
        "Network"
        "InstantMessaging"
      ];
      mimeType = [ "x-scheme-handler/discord" ];
      terminal = false;
      startupNotify = true;
      settings.StartupWMClass = "vesktop";
    };
    cursor = {
      name = "Cursor";
      genericName = "Text Editor";
      comment = "Code editor";
      exec = "${lib.getExe cursor.package} %F";
      icon = "${pkgs.code-cursor}/share/pixmaps/cursor.png";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      mimeType = ideMime;
      startupNotify = true;
      settings.StartupWMClass = "cursor";
    };
    code = {
      name = "Visual Studio Code";
      genericName = "Text Editor";
      exec = "${scripts}/code.sh %F";
      icon = "vscode";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      mimeType = ideMime;
      startupNotify = true;
      settings.StartupWMClass = "code";
    };
    obsidian = {
      name = "Obsidian";
      exec = "${scripts}/obsidian.sh %U";
      icon = "${pkgs.obsidian}/share/icons/hicolor/256x256/apps/obsidian.png";
      categories = [ "Office" ];
      mimeType = [ "x-scheme-handler/obsidian" ];
      startupNotify = true;
    };
    openlens = {
      name = "OpenLens";
      genericName = "Kubernetes IDE";
      exec = "${scripts}/openlens.sh";
      icon = "${pkgs.openlens}/share/icons/hicolor/512x512/apps/openlens.png";
      categories = [ "Development" ];
      startupNotify = true;
      settings.StartupWMClass = "open-lens";
    };
    libreoffice-startcenter = {
      name = "LibreOffice";
      exec = "${scripts}/libreoffice.sh";
      icon = "libreoffice-startcenter";
      categories = [ "Office" ];
      startupNotify = true;
    };
    libreoffice-writer = {
      name = "LibreOffice Writer";
      genericName = "Word Processor";
      exec = "${scripts}/libreoffice.sh --writer %U";
      icon = "libreoffice-writer";
      categories = [
        "Office"
        "WordProcessor"
      ];
      mimeType = [
        "application/msword"
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        "application/vnd.oasis.opendocument.text"
      ];
      startupNotify = true;
    };
    libreoffice-calc = {
      name = "LibreOffice Calc";
      genericName = "Spreadsheet";
      exec = "${scripts}/libreoffice.sh --calc %U";
      icon = "libreoffice-calc";
      categories = [
        "Office"
        "Spreadsheet"
      ];
      mimeType = [
        "application/vnd.ms-excel"
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      ];
      startupNotify = true;
    };
    libreoffice-impress = {
      name = "LibreOffice Impress";
      genericName = "Presentation";
      exec = "${scripts}/libreoffice.sh --impress %U";
      icon = "libreoffice-impress";
      categories = [
        "Office"
        "Presentation"
      ];
      mimeType = [
        "application/vnd.ms-powerpoint"
        "application/vnd.openxmlformats-officedocument.presentationml.presentation"
      ];
      startupNotify = true;
    };
    libreoffice-draw = {
      name = "LibreOffice Draw";
      exec = "${scripts}/libreoffice.sh --draw %U";
      icon = "libreoffice-draw";
      categories = [ "Office" ];
      startupNotify = true;
    };
    idea-ultimate = {
      name = "IntelliJ IDEA Ultimate";
      genericName = "Java IDE";
      comment = "Java IDE";
      exec = "${scripts}/idea-ultimate.sh %F";
      icon = "${pkgs.jetbrains.idea}/idea/bin/idea.svg";
      categories = [
        "Development"
        "IDE"
      ];
      mimeType = [
        "text/plain"
        "inode/directory"
      ];
      startupNotify = true;
      settings.StartupWMClass = "jetbrains-idea";
    };
    chrome-az = {
      name = "Chrome Aziza";
      genericName = "Web Browser";
      exec = "${scripts}/chrome-az.sh %U";
      icon = "google-chrome";
      categories = [
        "Network"
        "WebBrowser"
      ];
      startupNotify = true;
      settings.StartupWMClass = "chrome-az";
    };
    chrome-hika = {
      name = "Chrome hika911";
      genericName = "Web Browser";
      exec = "${scripts}/chrome-hika.sh %U";
      icon = "google-chrome";
      categories = [
        "Network"
        "WebBrowser"
      ];
      startupNotify = true;
      settings.StartupWMClass = "chrome-hika";
    };
    chrome-sciencesoft = {
      name = "Chrome ScienceSoft";
      genericName = "Web Browser";
      exec = "${scripts}/chrome-sciencesoft.sh %U";
      icon = "google-chrome";
      categories = [
        "Network"
        "WebBrowser"
      ];
      startupNotify = true;
      settings.StartupWMClass = "chrome-sciencesoft";
    };
    firefox = {
      name = "Firefox";
      genericName = "Web Browser";
      exec = "${scripts}/firefox.sh";
      icon = "${pkgs.firefox}/share/icons/hicolor/128x128/apps/firefox.png";
      categories = [
        "Network"
        "WebBrowser"
      ];
      startupNotify = true;
      settings.StartupWMClass = "firefox";
    };
    zen = {
      name = "Zen";
      genericName = "Web Browser";
      exec = "${scripts}/zen.sh";
      icon = "${zenBrowser}/share/icons/hicolor/128x128/apps/zen.png";
      categories = [
        "Network"
        "WebBrowser"
      ];
      startupNotify = true;
      settings.StartupWMClass = "zen";
    };
    spotify = {
      name = "Spotify";
      genericName = "Music Player";
      exec = "${scripts}/spotify.sh";
      icon = "spotify-client";
      categories = [
        "Audio"
        "Music"
      ];
      mimeType = [ "x-scheme-handler/spotify" ];
      startupNotify = true;
      settings.StartupWMClass = "spotify";
    };
    telegram-1 = {
      name = "Telegram 1";
      exec = "${scripts}/telegram-1.sh %U";
      icon = "org.telegram.desktop";
      categories = [
        "Network"
        "InstantMessaging"
      ];
      mimeType = [
        "x-scheme-handler/tg"
        "x-scheme-handler/telegram"
        "x-scheme-handler/tonsite"
      ];
      startupNotify = true;
    };
    telegram-2 = {
      name = "Telegram 2";
      exec = "${scripts}/telegram-2.sh";
      icon = "org.telegram.desktop";
      categories = [
        "Network"
        "InstantMessaging"
      ];
      startupNotify = true;
    };
    writer = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    calc = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    impress = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    draw = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    startcenter = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    math = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    base = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    xsltfilter = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    code-url-handler = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    "org.telegram.desktop" = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    idea-oss = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
    AmneziaVPN = {
      name = "Hidden";
      exec = "true";
      noDisplay = true;
      settings.Hidden = "true";
    };
  };

  home.file."vms/ubuntu/Vagrantfile".source = ./dots/vagrant/ubuntu/Vagrantfile;

  systemd.user.services.hypr-fix-safe-mode = {
    Unit = {
      Description = "Restore Hyprland rice after watchdog safe-mode";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${config.home.homeDirectory}/.config/scripts/hypr-fix-safe-mode.sh loop";
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.cap-fossilize = {
    Unit = {
      Description = "Pin Steam fossilize_replay to two idle cores";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${config.home.homeDirectory}/.config/scripts/cap-fossilize.sh loop";
      Restart = "always";
      RestartSec = 10;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.container-window-reaper = {
    Unit = {
      Description = "Drop ghost Hyprland windows after isolated containers exit";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${config.home.homeDirectory}/.config/scripts/reap-container-windows watch";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.telegram-link = {
    Unit.Description = "Open a t.me or tg: link in Telegram 1";
    Service = {
      Type = "oneshot";
      ExecStart = "${config.home.homeDirectory}/.config/scripts/telegram-link-dispatch.sh";
    };
  };

  systemd.user.paths.telegram-link = {
    Unit.Description = "Watch for Telegram links from browsers";
    Path.PathChanged = [
      "${config.home.homeDirectory}/programs/telegram-1/ipc/telegram.url"
      "${config.home.homeDirectory}/programs/chrome-dd/ipc/telegram.url"
      "${config.home.homeDirectory}/programs/chrome-az/ipc/telegram.url"
      "${config.home.homeDirectory}/programs/chrome-hika/ipc/telegram.url"
      "${config.home.homeDirectory}/programs/firefox/ipc/telegram.url"
      "${config.home.homeDirectory}/programs/zen/ipc/telegram.url"
      "${config.home.homeDirectory}/programs/ipc/telegram.url"
    ];
    Install.WantedBy = [ "default.target" ];
  };
}
