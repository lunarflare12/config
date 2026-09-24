{
  config,
  lib,
  pkgs,
  params,
  ...
}:

{
  imports = [
    ./hyprland.nix
    ./hyprlock.nix
    ./kitty.nix
    ./theme.nix
    ./shell.nix
    ./apps.nix
    ./quickshell.nix
    ./obs.nix
    ./git.nix
    ./insta360.nix
    ./libreoffice.nix
    ./thunar.nix
    ./cursors.nix
  ];

  home.stateVersion = params.stateVersion;

  home.pointerCursor = {
    enable = true;
    name = "macOS";
    package = pkgs.apple-cursor;
    size = params.cursorSize;
    gtk.enable = true;
    x11.enable = true;
  };

  home.sessionVariables = {
    TERMINAL = params.terminal;
    BROWSER = params.browser;
    EDITOR = "nvim";
    HYPRSHOT_DIR = "${config.home.homeDirectory}/Pictures/Screenshots";
    VAGRANT_DEFAULT_PROVIDER = "libvirt";
    LIBVIRT_DEFAULT_URI = "qemu:///system";
  };

  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = {
        "text/html" = "${params.browser}.desktop";
        "application/xhtml+xml" = "${params.browser}.desktop";
        "x-scheme-handler/http" = "${params.browser}.desktop";
        "x-scheme-handler/https" = "${params.browser}.desktop";
        "x-scheme-handler/about" = "${params.browser}.desktop";
        "x-scheme-handler/unknown" = "${params.browser}.desktop";
        "x-scheme-handler/tg" = "telegram-1.desktop";
        "x-scheme-handler/telegram" = "telegram-1.desktop";
        "x-scheme-handler/tonsite" = "telegram-1.desktop";
        "application/pdf" = "org.pwmt.zathura.desktop";
        "application/epub+zip" = "org.pwmt.zathura.desktop";
        "application/msword" = "libreoffice-writer.desktop";
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document" =
          "libreoffice-writer.desktop";
        "application/vnd.oasis.opendocument.text" = "libreoffice-writer.desktop";
        "application/vnd.ms-excel" = "libreoffice-calc.desktop";
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" = "libreoffice-calc.desktop";
        "application/vnd.ms-powerpoint" = "libreoffice-impress.desktop";
        "application/vnd.openxmlformats-officedocument.presentationml.presentation" =
          "libreoffice-impress.desktop";
        "inode/directory" = "thunar.desktop";
      };
    };
    configFile."mimeapps.list".force = true;
  };

  # Stale *.hm.bak and a hand-enabled OpenCluely wants link block checkLinkTargets.
  home.activation.dropStaleHmBackups = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    configHome="${config.xdg.configHome}"
    find "$configHome/aurora" "$configHome/hypr" "$configHome/systemd" "$configHome/gtk-3.0" "$configHome/gtk-4.0" \
      \( -name '*.hm.bak' -o -name '*.hm.bak.prev' -o -name '*.prev' \) -delete 2>/dev/null || true
    rm -f "$configHome/hypr/ow-vkfix-dir" "$configHome/hypr/ow-vkfix-dir.prev"

    wantsDir="$configHome/systemd/user/graphical-session.target.wants"
    for name in opencluely.service obs-tray.service insta360-hold.service telegram-link.service telegram-link.path; do
      rm -f "$wantsDir/$name"
      unit="$configHome/systemd/user/$name"
      if [ -e "$unit" ] && [ ! -L "$unit" ]; then
        rm -f "$unit"
      fi
    done

    # Hand-copied / old-generation desktops shadow HM wrappers (cursor.sh, idea-ultimate.sh).
    apps="$HOME/.local/share/applications"
    for name in cursor.desktop idea-ultimate.desktop idea-oss.desktop com.obsproject.Studio.desktop steam.desktop \
      google-chrome.desktop com.google.Chrome.desktop chrome-az.desktop chrome-hika.desktop \
      firefox.desktop zen.desktop code.desktop code-url-handler.desktop obsidian.desktop \
      openlens.desktop spotify.desktop telegram-1.desktop telegram-2.desktop \
      libreoffice-startcenter.desktop libreoffice-writer.desktop libreoffice-calc.desktop \
      libreoffice-impress.desktop libreoffice-draw.desktop; do
      target="$apps/$name"
      if [ -e "$target" ] && [ ! -L "$target" ]; then
        rm -f "$target"
      fi
    done
    rm -f "$apps"/*.desktop.hm.bak "$apps"/*.desktop.hm.bak.prev
  '';
}
