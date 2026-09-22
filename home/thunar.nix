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
    pkgs.finder-pick
    (lib.hiPrio (
      pkgs.writeShellScriptBin "thunar" ''
        exec "${finderExec}" "$@"
      ''
    ))
  ];

  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${scripts}/finder-pick.sh
    default_dir=${homeDir}
    open_mode=suggested
    save_mode=suggested
    create_help_file=0
  '';

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
    hidden-bookmarks = [
      "recent:///"
      "file://${homeDir}"
    ];
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
    shortcuts-icon-emblems = false;
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

  xdg.configFile."gtk-3.0/bookmarks" = {
    force = true;
    text = ''
      file:/// Root
      file://${homeDir}/Desktop Desktop
      file://${homeDir}/Documents Documents
      file://${homeDir}/Downloads Downloads
      file://${homeDir}/Pictures Pictures
    '';
  };

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
    "org.xfce.thunar" = finderEntry // {
      noDisplay = true;
    };
    Finder = finderEntry // {
      noDisplay = true;
    };
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

  # Hide GNOME/Thunar chain badge on aliases. Custom emblems still work.
  xdg.dataFile."icons/hicolor/scalable/emblems/emblem-symbolic-link.svg" = {
    text = ''<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"/>'';
    force = true;
  };

  gtk.gtk3.extraCss = ''
    @import url("${homeDir}/.config/aurora/gtk-colors.css");

    window.thunar,
    window.thunarwindow,
    .thunar {
      border-radius: 18px;
      background-color: alpha(@theme_bg_color, 0.52);
      background-image: none;
    }

    window.thunar headerbar,
    window.thunarwindow headerbar,
    .thunar headerbar,
    window.thunar .titlebar,
    .thunar .titlebar {
      min-height: 48px;
      padding: 4px 10px 4px 10px;
      background-color: alpha(@theme_bg_color, 0.48);
      background-image: none;
      box-shadow: none;
      border: none;
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

    /* Path-bar left chevron is always allocated (~slider_width) even at Home.
       WhiteSur has no pan-start-symbolic, so it paints an empty pill. Thunar
       also size-allocates that slot in C, so min-width:0 cannot collapse it —
       hide the chrome and pull crumbs over the reserved width. */
    window.thunar .path-bar.linked > *:first-child,
    .thunar .path-bar.linked > *:first-child,
    window.thunar thunarlocationbuttons > *:first-child,
    .thunar thunarlocationbuttons > *:first-child {
      opacity: 0;
      min-width: 0;
      min-height: 0;
      padding: 0;
      margin: 0;
      border: none;
      background: none;
      background-image: none;
      box-shadow: none;
      outline: none;
      -gtk-icon-transform: scale(0);
    }

    window.thunar .path-bar.linked > *:first-child image,
    window.thunar .path-bar.linked > *:first-child label,
    .thunar .path-bar.linked > *:first-child image,
    .thunar .path-bar.linked > *:first-child label {
      opacity: 0;
      min-width: 0;
      min-height: 0;
      padding: 0;
      margin: 0;
    }

    window.thunar .sidebar,
    .thunar .shortcuts-pane,
    window.thunar paned > widget:nth-child(1) {
      min-width: 200px;
      background-color: alpha(@theme_bg_color, 0.38);
      background-image: none;
    }

    window.thunar .sidebar .view,
    .thunar .sidebar .view,
    window.thunar .shortcuts-pane .view,
    .thunar treeview.view {
      font-size: 13px;
      padding: 8px 0;
      color: alpha(@theme_fg_color, 0.92);
    }

    window.thunar .sidebar .view:hover,
    .thunar .shortcuts-pane .view:hover {
      background-color: alpha(@theme_selected_bg_color, 0.22);
      color: @theme_selected_fg_color;
      border-radius: 8px;
    }

    window.thunar .sidebar .view:selected,
    window.thunar .sidebar .view:selected:focus,
    window.thunar .sidebar .view:selected:hover,
    .thunar .shortcuts-pane .view:selected,
    .thunar .shortcuts-pane .view:selected:focus {
      background-color: alpha(@theme_selected_bg_color, 0.42);
      color: @theme_selected_fg_color;
      border-radius: 8px;
    }

    window.thunar .standard-view,
    .thunar .standard-view {
      padding: 0;
      background-color: transparent;
      background-image: none;
    }

    window.thunar iconview,
    .thunar iconview {
      padding: 18px 16px;
      background-color: transparent;
      background-image: none;
    }

    window.thunar .view,
    .thunar .view {
      background-color: transparent;
      background-image: none;
    }

    window.thunar iconview:selected,
    window.thunar iconview:selected:focus,
    window.thunar iconview:selected:hover,
    .thunar iconview:selected,
    .thunar iconview:selected:focus,
    window.thunar .view:selected,
    window.thunar .view:selected:focus,
    .thunar .view:selected,
    window.thunar .standard-view .view:selected,
    window.thunar .standard-view treeview.view:selected,
    window.thunar .standard-view treeview.view:selected:focus,
    window.thunar .standard-view treeview.view:selected:hover {
      background-color: alpha(@theme_selected_bg_color, 0.40);
      color: @theme_selected_fg_color;
      border-radius: 0;
    }

    window.thunar iconview:hover,
    .thunar iconview:hover,
    window.thunar .view:hover,
    .thunar .view:hover,
    window.thunar .standard-view .view:hover,
    window.thunar .standard-view treeview.view:hover {
      background-color: alpha(@theme_selected_bg_color, 0.18);
      border-radius: 0;
    }

    window.thunar .path-bar button:checked,
    window.thunar .path-bar button:checked:hover,
    .thunar .path-bar button:checked,
    window.thunar .linked.path-bar > button:checked,
    .thunar .linked.path-bar > button:checked {
      background-color: alpha(@theme_selected_bg_color, 0.36);
      color: @theme_selected_fg_color;
    }

    window.thunar entry selection,
    window.thunar text selection,
    .thunar entry selection,
    .thunar text selection {
      background-color: @theme_selected_bg_color;
      color: @theme_selected_fg_color;
    }

    window.thunar treeview header button,
    .thunar treeview header button {
      border-radius: 0;
    }

    window.thunar statusbar,
    .thunar statusbar {
      padding: 2px 14px;
      font-size: 12px;
      background-color: alpha(@theme_bg_color, 0.42);
      background-image: none;
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
      background-color: alpha(@theme_selected_bg_color, 0.36);
      color: @theme_selected_fg_color;
    }

    menu separator {
      margin: 5px 10px;
    }
  '';
}
