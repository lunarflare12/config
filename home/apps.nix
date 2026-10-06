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
  aurora = lib.getExe pkgs.aurora-helpers;
  aShim =
    name: subcmd:
    (pkgs.writeShellApplication {
      inherit name;
      text = ''exec ${aurora} ${subcmd} "$@"'';
    }).overrideAttrs
      (old: {
        meta = (old.meta or { }) // {
          priority = 0;
        };
      });
  repoRoot = "${config.home.homeDirectory}/${params.repo}";
  containersDots = "${repoRoot}/home/dots/containers";
  # Static compose/Dockerfile/entrypoint live in the git tree; ~/containers is just a view.
  linkContainer = dir: name: {
    "containers/${dir}/${name}" = {
      source = config.lib.file.mkOutOfStoreSymlink "${containersDots}/${dir}/${name}";
      force = true;
    };
  };
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
    exec = "${lib.getExe (aShim "google-chrome" "apps chrome")} %U";
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

  inherit (spaces) cursor;
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

  home.packages = [
    pkgs.aurora-helpers
    pkgs.xrandr
    spaces.discord.package
    spaces.cursor.package
    spaces.spotify.package
    spaces.idea-ultimate.package
    spaces.telegram-2.package
    (aShim "google-chrome" "apps chrome")
    (aShim "chrome-az" "apps chrome-az")
    (aShim "chrome-hika" "apps chrome-hika")
    (aShim "chrome-sciencesoft" "apps chrome-sciencesoft")
    (aShim "firefox" "apps firefox")
    (aShim "zen" "apps zen")
    (aShim "telegram-1" "apps telegram-1")
    (aShim "telegram" "apps telegram-1")
    (aShim "telegram-2" "apps telegram-2")
    (aShim "steam" "game steam")
    (aShim "terraria" "game terraria")
    (aShim "albion" "game albion")
    (aShim "alien-shooter" "game alien-shooter")
    (aShim "generals" "game generals")
    (aShim "code" "apps code")
    (aShim "obsidian" "apps obsidian")
    (aShim "openlens" "apps openlens")
    (aShim "libreoffice" "apps libreoffice")
    (aShim "soffice" "apps libreoffice")
    (aShim "discord" "apps discord")
    (aShim "spotify" "apps spotify")
    (aShim "cursor" "apps cursor")
    (aShim "idea-ultimate" "apps idea")
    (aShim "finder" "finder")
    (aShim "obs" "obs")
    (aShim "insta360-link" "insta360")
    (aShim "prismlauncher" "apps prismlauncher")
    (aShim "qbittorrent" "apps qbittorrent")
    (aShim "wayland-box" "box")
  ];

  # Keep store paths for containerized apps without installing their .desktop files.
  # Steam FHS is pinned via /etc/aurora/steam-bin (modules/steam.nix), not here.
  # Compose/Dockerfile/entrypoint → git tree. .env + launchers stay HM-generated.
  home.file = lib.mkMerge [
    {
      ".local/share/aurora/container-store-refs".text = ''
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
    }
    (linkContainer "apps" "compose.yml")
    (linkContainer "apps" "Dockerfile")
    (linkContainer "apps" "chrome-policy.json")
    (linkContainer "steam" "compose.yml")
    (linkContainer "steam" "Dockerfile")
    (linkContainer "steam" "steam-profile")
    (linkContainer "telegram" "compose.yml")
    (linkContainer "telegram" "Dockerfile")
    (linkContainer "telegram" "td-setup.tar.xz")
    (linkContainer "llm" "compose.yml")
    (linkContainer "llm" ".env.example")
    (linkContainer "llm" "settings.yml.example")
    {
      "containers/apps/.env" = {
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

      "containers/apps/launch-vscode.sh" = {
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

      "containers/apps/launch-openlens.sh" = {
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
    }
    { "vms/ubuntu/Vagrantfile".source = ./dots/vagrant/ubuntu/Vagrantfile; }
  ];

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
      exec = "${lib.getExe (aShim "steam" "game steam")} %U";
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
      exec = "${lib.getExe (aShim "albion" "game albion")}";
      icon = "steam_icon_761890";
      categories = [ "Game" ];
      terminal = false;
      settings.StartupWMClass = "steam_app_761890";
    };
    terraria = {
      name = "Terraria";
      exec = "${lib.getExe (aShim "terraria" "game terraria")}";
      icon = "steam_icon_105600";
      categories = [ "Game" ];
      terminal = false;
      settings.StartupWMClass = "steam_app_105600";
    };
    alien-shooter = {
      name = "Alien Shooter";
      exec = "${lib.getExe (aShim "alien-shooter" "game alien-shooter")}";
      icon = "steam_icon_33100";
      categories = [ "Game" ];
      terminal = false;
      settings.StartupWMClass = "steam_app_33100";
    };
    generals = {
      name = "C&C Generals Online";
      exec = "${lib.getExe (aShim "generals" "game generals")}";
      icon = "applications-games";
      categories = [ "Game" ];
      terminal = false;
      settings.StartupWMClass = "steam_proton";
    };
    discord = {
      name = "Discord";
      exec = "${lib.getExe (aShim "discord" "apps discord")}";
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
      exec = "${lib.getExe (aShim "code" "apps code")} %F";
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
      exec = "${lib.getExe (aShim "obsidian" "apps obsidian")} %U";
      icon = "${pkgs.obsidian}/share/icons/hicolor/256x256/apps/obsidian.png";
      categories = [ "Office" ];
      mimeType = [ "x-scheme-handler/obsidian" ];
      startupNotify = true;
    };
    openlens = {
      name = "OpenLens";
      genericName = "Kubernetes IDE";
      exec = "${lib.getExe (aShim "openlens" "apps openlens")}";
      icon = "${pkgs.openlens}/share/icons/hicolor/512x512/apps/openlens.png";
      categories = [ "Development" ];
      startupNotify = true;
      settings.StartupWMClass = "open-lens";
    };
    libreoffice-startcenter = {
      name = "LibreOffice";
      exec = "${lib.getExe (aShim "libreoffice" "apps libreoffice")}";
      icon = "libreoffice-startcenter";
      categories = [ "Office" ];
      startupNotify = true;
    };
    libreoffice-writer = {
      name = "LibreOffice Writer";
      genericName = "Word Processor";
      exec = "${lib.getExe (aShim "libreoffice" "apps libreoffice")} --writer %U";
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
      exec = "${lib.getExe (aShim "libreoffice" "apps libreoffice")} --calc %U";
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
      exec = "${lib.getExe (aShim "libreoffice" "apps libreoffice")} --impress %U";
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
      exec = "${lib.getExe (aShim "libreoffice" "apps libreoffice")} --draw %U";
      icon = "libreoffice-draw";
      categories = [ "Office" ];
      startupNotify = true;
    };
    idea-ultimate = {
      name = "IntelliJ IDEA Ultimate";
      genericName = "Java IDE";
      comment = "Java IDE";
      exec = "${lib.getExe (aShim "idea-ultimate" "apps idea")} %F";
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
      exec = "${lib.getExe (aShim "chrome-az" "apps chrome-az")} %U";
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
      exec = "${lib.getExe (aShim "chrome-hika" "apps chrome-hika")} %U";
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
      exec = "${lib.getExe (aShim "chrome-sciencesoft" "apps chrome-sciencesoft")} %U";
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
      exec = "${lib.getExe (aShim "firefox" "apps firefox")}";
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
      exec = "${lib.getExe (aShim "zen" "apps zen")}";
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
      exec = "${lib.getExe (aShim "spotify" "apps spotify")}";
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
      exec = "${lib.getExe (aShim "telegram-1" "apps telegram-1")} %U";
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
      exec = "${lib.getExe (aShim "telegram-2" "apps telegram-2")}";
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

  systemd.user.services.hypr-fix-safe-mode = {
    Unit = {
      Description = "Restore Hyprland rice after watchdog safe-mode";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.aurora-helpers} hypr-fix loop";
      Restart = "always";
      RestartSec = 3;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # Caps only aurora/shader-ctl background fossilize (see fossilize.go).
  # Must never pin Steam's Play-time --quiet-slave compile — that made OW
  # ProcessingShaderCache crawl for hours on two nice-19 cores.
  systemd.user.services.cap-fossilize = {
    Unit = {
      Description = "Cap background (non-Steam) fossilize_replay only";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.aurora-helpers} fossilize loop";
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
      ExecStart = "${lib.getExe pkgs.aurora-helpers} reaper watch";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.telegram-link = {
    Unit.Description = "Open a t.me or tg: link in Telegram 1";
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.aurora-helpers} dispatch telegram-link";
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

  # Container xdg-open / FileManager1 → host Finder or default app.
  systemd.user.services.container-open = {
    Unit = {
      Description = "Open or reveal a path handed out of an isolated container";
      # Path unit can fire a burst when Telegram writes open+launch together.
      StartLimitIntervalSec = 10;
      StartLimitBurst = 20;
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe pkgs.aurora-helpers} dispatch open";
    };
  };

  systemd.user.paths.container-open = {
    Unit.Description = "Watch container ipc for open/reveal requests";
    Path.PathChanged = [
      "${config.home.homeDirectory}/programs/chrome-dd/ipc/open.path"
      "${config.home.homeDirectory}/programs/chrome-dd/ipc/launch.path"
      "${config.home.homeDirectory}/programs/chrome-az/ipc/open.path"
      "${config.home.homeDirectory}/programs/chrome-az/ipc/launch.path"
      "${config.home.homeDirectory}/programs/chrome-hika/ipc/open.path"
      "${config.home.homeDirectory}/programs/chrome-hika/ipc/launch.path"
      "${config.home.homeDirectory}/programs/chrome-sciencesoft/ipc/open.path"
      "${config.home.homeDirectory}/programs/chrome-sciencesoft/ipc/launch.path"
      "${config.home.homeDirectory}/programs/firefox/ipc/open.path"
      "${config.home.homeDirectory}/programs/firefox/ipc/launch.path"
      "${config.home.homeDirectory}/programs/zen/ipc/open.path"
      "${config.home.homeDirectory}/programs/zen/ipc/launch.path"
      "${config.home.homeDirectory}/programs/telegram-1/ipc/open.path"
      "${config.home.homeDirectory}/programs/telegram-1/ipc/launch.path"
      "${config.home.homeDirectory}/programs/telegram-2/ipc/open.path"
      "${config.home.homeDirectory}/programs/telegram-2/ipc/launch.path"
    ];
    Install.WantedBy = [ "default.target" ];
  };
}
