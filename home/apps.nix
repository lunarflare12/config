{ lib, pkgs, params, inputs, ... }:

let
  fileManagers = {
    thunar = pkgs.thunar;
  };

  zenBrowser =
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
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

  home.packages = [
    (fileManagers.${params.fileManager} or pkgs.${params.fileManager})
    zenBrowser
    pkgs.xrandr
  ]
  ++ lib.optional (params.browser != "firefox") pkgs.${params.browser};

  # Electron/Chrome ignore GTK unless they are launched with dark flags.
  xdg.desktopEntries = {
    google-chrome = {
      name = "Google Chrome";
      genericName = "Web Browser";
      exec = "${pkgs.google-chrome}/bin/google-chrome-stable --force-dark-mode --enable-features=WebUIDarkMode %U";
      icon = "google-chrome";
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "application/pdf"
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      startupNotify = true;
    };
    cursor = {
      name = "Cursor";
      genericName = "Text Editor";
      exec = "${pkgs.code-cursor}/bin/cursor --force-dark-mode %F";
      icon = "cursor";
      categories = [ "Utility" "TextEditor" "Development" "IDE" ];
      mimeType = [ "application/x-code-workspace" "text/plain" "inode/directory" ];
      startupNotify = true;
    };
    code = {
      name = "Visual Studio Code";
      genericName = "Text Editor";
      exec = "${pkgs.vscode}/bin/code --force-dark-mode %F";
      icon = "vscode";
      categories = [ "Utility" "TextEditor" "Development" "IDE" ];
      mimeType = [ "application/x-code-workspace" "text/plain" "inode/directory" ];
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
  };

  home.file."vms/ubuntu/Vagrantfile".source = ./dots/vagrant/ubuntu/Vagrantfile;
}
