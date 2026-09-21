{
  config,
  lib,
  pkgs,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  scripts = "${homeDir}/.config/scripts";
  finderIcon = ./dots/aurora-qs/assets/finder-icon.png;
  finderExec = "${scripts}/finder.sh";
  finderAction = "${scripts}/finder-action.sh";
  finderEntry = {
    name = "Finder";
    genericName = "File Manager";
    comment = "Browse files and folders";
    exec = "${finderExec} %U";
    icon = "${finderIcon}";
    terminal = false;
    startupNotify = true;
    mimeType = [ "inode/directory" ];
    categories = [
      "System"
      "Utility"
      "Core"
      "FileTools"
      "FileManager"
      "GTK"
    ];
    settings.StartupWMClass = "thunar";
  };
in
{
  home.packages = [
    pkgs.file-roller
    pkgs.ffmpegthumbnailer
    pkgs.webp-pixbuf-loader
    pkgs.zenity
    (lib.hiPrio (
      pkgs.writeShellScriptBin "thunar" ''
        exec "${finderExec}" "$@"
      ''
    ))
  ];

  xfconf.settings.thunar = {
    last-view = "ThunarIconView";
    last-icon-view-zoom-level = "THUNAR_ZOOM_LEVEL_100_PERCENT";
    last-details-view-zoom-level = "THUNAR_ZOOM_LEVEL_50_PERCENT";
    last-separator-position = 220;
    last-window-width = 1180;
    last-window-height = 740;
    last-window-maximized = false;
    last-show-hidden = false;
    last-sort-column = "THUNAR_COLUMN_NAME";
    last-sort-order = "GTK_SORT_ASCENDING";
    last-location-bar = "ThunarLocationButtons";
    last-side-pane = "ThunarShortcutsPane";
    last-menubar-visible = false;
    last-statusbar-visible = true;
    last-image-preview-visible = false;
    misc-single-click = false;
    misc-folders-first = true;
    misc-text-beside-icons = false;
    misc-date-style = "THUNAR_DATE_STYLE_LONG";
    misc-middle-click-in-tab = true;
    misc-full-path-in-title = false;
    misc-symbolic-icons-in-toolbar = true;
    misc-symbolic-icons-in-side-pane = false;
    misc-change-window-icon = true;
    misc-show-delete-action = false;
    misc-small-toolbar-icons = false;
    misc-always-show-tabs = false;
    misc-open-new-window-as-tab = false;
    shortcuts-icon-size = "THUNAR_ICON_SIZE_24";
    shortcuts-icon-emblems = true;
  };

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    desktop = "${homeDir}/Desktop";
    documents = "${homeDir}/Documents";
    download = "${homeDir}/Downloads";
    music = "${homeDir}/Music";
    pictures = "${homeDir}/Pictures";
    videos = "${homeDir}/Videos";
    templates = "${homeDir}/Templates";
    publicShare = "${homeDir}/Public";
  };

  xdg.configFile."gtk-3.0/bookmarks".text = ''
    file://${homeDir}/Desktop Desktop
    file://${homeDir}/Documents Documents
    file://${homeDir}/Downloads Downloads
    file://${homeDir}/Pictures Pictures
    file://${homeDir}/Videos Movies
    file://${homeDir}/Music Music
    file://${homeDir} Home
  '';

  xdg.configFile."Thunar/uca.xml" = {
    force = true;
    text = ''
      <?xml version="1.0" encoding="UTF-8"?>
      <actions>
      <action>
        <icon>folder-open</icon>
        <name>Open in New Window</name>
        <unique-id>aurora-finder-new-window</unique-id>
        <command>${finderAction} new-window %f</command>
        <description>Open this folder in a new window</description>
        <patterns>*</patterns>
        <directories/>
      </action>
      <action>
        <icon>document-properties</icon>
        <name>Get Info</name>
        <unique-id>aurora-finder-info</unique-id>
        <command>${finderAction} info %F</command>
        <description>Show item info</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>edit-copy</icon>
        <name>Duplicate</name>
        <unique-id>aurora-finder-duplicate</unique-id>
        <command>${finderAction} duplicate %F</command>
        <description>Duplicate the selected items</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>emblem-symbolic-link</icon>
        <name>Make Alias</name>
        <unique-id>aurora-finder-alias</unique-id>
        <command>${finderAction} alias %F</command>
        <description>Create a symlink alias</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>view-fullscreen</icon>
        <name>Quick Look</name>
        <unique-id>aurora-finder-preview</unique-id>
        <command>${finderAction} preview %f</command>
        <description>Preview the selected item</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>package-x-generic</icon>
        <name>Compress</name>
        <unique-id>aurora-finder-compress</unique-id>
        <command>${finderAction} compress %F</command>
        <description>Compress with File Roller</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>send-to</icon>
        <name>Share</name>
        <unique-id>aurora-finder-share</unique-id>
        <command>${finderAction} share %F</command>
        <description>Copy items as file URIs</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>folder</icon>
        <name>Customise Folder…</name>
        <unique-id>aurora-finder-color</unique-id>
        <command>${finderAction} color %f</command>
        <description>Set a colour label on this folder</description>
        <patterns>*</patterns>
        <directories/>
      </action>
      <action>
        <icon>utilities-terminal</icon>
        <name>New Terminal at Folder</name>
        <unique-id>aurora-finder-terminal</unique-id>
        <command>${lib.getExe pkgs.kitty} --directory %f</command>
        <description>Open Terminal here</description>
        <patterns>*</patterns>
        <directories/>
      </action>
      <action>
        <icon>edit-copy</icon>
        <name>Copy Path</name>
        <unique-id>aurora-finder-copy-path</unique-id>
        <command>${pkgs.wl-clipboard}/bin/wl-copy -n %f</command>
        <description>Copy the full path</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      </actions>
    '';
  };

  xdg.desktopEntries = {
    thunar = finderEntry;
    "org.xfce.thunar" = finderEntry;
  };

  xdg.dataFile."icons/hicolor/256x256/apps/thunar.png" = {
    source = finderIcon;
    force = true;
  };
  xdg.dataFile."icons/hicolor/256x256/apps/org.xfce.thunar.png" = {
    source = finderIcon;
    force = true;
  };
  xdg.dataFile."icons/hicolor/256x256/apps/Finder.png" = {
    source = finderIcon;
    force = true;
  };

  gtk.gtk3.extraCss = ''
    window.thunar,
    window.thunarwindow,
    .thunar {
      border-radius: 18px;
    }

    window.thunar headerbar,
    window.thunarwindow headerbar,
    .thunar headerbar {
      min-height: 48px;
      padding: 4px 10px 4px 10px;
    }

    window.thunar toolbar,
    .thunar toolbar {
      padding: 2px 8px;
    }

    window.thunar toolbar button,
    .thunar toolbar button,
    window.thunar headerbar button,
    .thunar headerbar button {
      min-width: 30px;
      min-height: 26px;
      padding: 3px 7px;
      border-radius: 8px;
    }

    window.thunar .path-bar button,
    .thunar .path-bar button,
    window.thunar .linked.path-bar > button,
    .thunar .linked.path-bar > button {
      border-radius: 8px;
      padding: 2px 11px;
      font-weight: 600;
      min-height: 24px;
    }

    window.thunar .sidebar,
    .thunar .shortcuts-pane,
    window.thunar paned > widget:nth-child(1) {
      min-width: 200px;
    }

    window.thunar .sidebar .view,
    .thunar .sidebar .view,
    window.thunar .shortcuts-pane .view,
    .thunar treeview.view {
      font-size: 13px;
      padding: 8px 0;
    }

    window.thunar .standard-view,
    .thunar .standard-view,
    window.thunar iconview,
    .thunar iconview {
      padding: 18px 16px;
    }

    window.thunar iconview:selected,
    .thunar iconview:selected {
      border-radius: 10px;
    }

    window.thunar statusbar,
    .thunar statusbar {
      padding: 2px 14px;
      font-size: 12px;
    }

    /* Gtk menus are separate popup windows, not children of window.thunar. */
    menu {
      border-radius: 14px;
      padding: 6px 5px;
    }

    menuitem {
      border-radius: 6px;
      min-height: 24px;
      padding: 4px 12px;
    }

    menuitem:hover,
    menuitem:selected {
      border-radius: 6px;
    }

    menu separator {
      margin: 5px 10px;
    }
  '';
}
