{
  config,
  lib,
  pkgs,
  params,
  inputs,
  ...
}:

let
  scripts = "${config.home.homeDirectory}/.config/scripts";
  zenBrowser = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
  chromeBin = lib.getExe pkgs.google-chrome;
  ideaBin = lib.getExe pkgs.jetbrains.idea;
  chromeFlags = "--force-dark-mode --enable-features=WebUIDarkMode,MemorySaverMode --disable-features=SpareRendererForSitePerProcess --process-per-site --renderer-process-limit=8";
  chromeWrap = wrap "google-chrome" ''exec ${chromeBin} ${chromeFlags} "$@"'';
  steamWrap = wrap "steam" ''
    exec ${scripts}/steam.sh "$@"
  '';
  discordWrap = wrap "discord" ''
    export NIXOS_OZONE_WL=0
    export ELECTRON_OZONE_PLATFORM_HINT=x11
    exec ${lib.getExe pkgs.discord} --ozone-platform=x11 --disable-gpu --disable-gpu-compositing "$@"
  '';
  ideaWrap = wrap "idea-ultimate" ''
    export IDEA_ULTIMATE_BIN=${lib.escapeShellArg ideaBin}
    exec ${./dots/scripts/idea-ultimate.sh} "$@"
  '';
  chromeMime = [
    "application/pdf"
    "text/html"
    "text/xml"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
  ];
  chromeEntry = {
    name = "Google Chrome";
    genericName = "Web Browser";
    exec = "${scripts}/google-chrome.sh %U";
    icon = "google-chrome";
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = chromeMime;
    startupNotify = true;
  };
  ideMime = [
    "application/x-code-workspace"
    "text/plain"
    "inode/directory"
  ];
  wrap =
    name: command:
    pkgs.writeShellApplication {
      inherit name;
      text = command;
    };
in
{
  programs.firefox = lib.mkIf (params.browser == "firefox") {
    enable = true;
    profiles.default.settings = {
      "browser.theme.content-theme" = 0;
      "browser.theme.toolbar-theme" = 0;
      "extensions.activeThemeID" = "firefox-compact-dark@mozilla.org";
      "layout.css.prefers-color-scheme.content-override" = 0;
      "ui.systemUsesDarkTheme" = 1;
      "widget.gtk.respect-color-scheme" = true;
    };
  };

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

  home.sessionPath = [ scripts ];

  home.packages = [
    zenBrowser
    pkgs.xrandr
    chromeWrap
    steamWrap
    discordWrap
    ideaWrap
    (pkgs.runCommand "google-chrome-stable-bin" { } ''
      mkdir -p $out/bin
      ln -s ${lib.getExe chromeWrap} $out/bin/google-chrome-stable
    '')
    (wrap "wayland-box" ''exec ${./dots/scripts/wayland-box.sh} "$@"'')
  ]
  ++ lib.optional (
    params.browser != "firefox" && params.browser != "google-chrome"
  ) pkgs.${params.browser};

  xdg.desktopEntries = {
    google-chrome = chromeEntry;
    "com.google.Chrome" = chromeEntry;
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
    discord = {
      name = "Discord";
      exec = "${lib.getExe discordWrap}";
      icon = "discord";
      categories = [
        "Network"
        "InstantMessaging"
      ];
      mimeType = [ "x-scheme-handler/discord" ];
      terminal = false;
      startupNotify = true;
      settings.StartupWMClass = "discord";
    };
    cursor = {
      name = "Cursor";
      genericName = "Text Editor";
      exec = "${pkgs.code-cursor}/bin/cursor --force-dark-mode %F";
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
      exec = "${pkgs.vscode}/bin/code --force-dark-mode %F";
      icon = "vscode";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      mimeType = ideMime;
      startupNotify = true;
    };
    obsidian = {
      name = "Obsidian";
      exec = "${pkgs.obsidian}/bin/obsidian --force-dark-mode %U";
      icon = "obsidian";
      categories = [ "Office" ];
      mimeType = [ "x-scheme-handler/obsidian" ];
      startupNotify = true;
    };
    idea-ultimate = {
      name = "IntelliJ IDEA Ultimate";
      genericName = "Java IDE";
      exec = "${lib.getExe ideaWrap} %F";
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
  };

  home.file."vms/ubuntu/Vagrantfile".source = ./dots/vagrant/ubuntu/Vagrantfile;

  systemd.user.services.opencluely = {
    Unit = {
      Description = "OpenCluely (Go)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
      ConditionEnvironment = "WAYLAND_DISPLAY";
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "${config.home.homeDirectory}/projects/opencluely";
      ExecStart = "${config.home.homeDirectory}/projects/opencluely/opencluely tray";
      Environment = "PATH=/run/current-system/sw/bin:/etc/profiles/per-user/${config.home.username}/bin";
      Restart = "on-failure";
      RestartSec = "5";
      KillMode = "mixed";
      TimeoutStopSec = "15";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
