{
  config,
  lib,
  pkgs,
  params,
  ...
}:

{
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
        "x-scheme-handler/http" = "${params.browser}.desktop";
        "x-scheme-handler/https" = "${params.browser}.desktop";
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
    find "$configHome/aurora" "$configHome/hypr" "$configHome/systemd" -name '*.hm.bak' -delete 2>/dev/null || true
    rm -f "$configHome/hypr/ow-vkfix-dir"

    unit="$configHome/systemd/user/opencluely.service"
    wants="$configHome/systemd/user/graphical-session.target.wants/opencluely.service"
    rm -f "$wants"
    if [ -e "$unit" ] && [ ! -L "$unit" ]; then
      rm -f "$unit"
    fi
  '';

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
    ./spicetify.nix
  ];
}
