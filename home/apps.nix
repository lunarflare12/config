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
    (pkgs.${params.fileManager} or pkgs.thunar)
    zenBrowser
    pkgs.xrandr
    (pkgs.writeShellScriptBin "google-chrome-stable" ''
      exec ${scripts}/google-chrome.sh "$@"
    '')
    (pkgs.writeShellScriptBin "google-chrome" ''
      exec ${scripts}/google-chrome.sh "$@"
    '')
    (pkgs.writeShellScriptBin "steam" ''
      exec ${scripts}/steam.sh "$@"
    '')
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
    cursor = {
      name = "Cursor";
      genericName = "Text Editor";
      exec = "${pkgs.code-cursor}/bin/cursor --force-dark-mode %F";
      icon = "cursor";
      categories = [
        "Utility"
        "TextEditor"
        "Development"
        "IDE"
      ];
      mimeType = ideMime;
      startupNotify = true;
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
      exec = "idea-ultimate %F";
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
      startupWMClass = "jetbrains-idea";
    };
  };

  home.file."vms/ubuntu/Vagrantfile".source = ./dots/vagrant/ubuntu/Vagrantfile;
}
