{
  config,
  lib,
  pkgs,
  params,
  desktopEnv,
  ...
}:

let
  themeData = import ../lib/themes.nix;
  themeNames = builtins.attrNames themeData.themes;
  toLua = import ../lib/to-lua.nix { inherit lib; };
  env = desktopEnv;
  defaultTheme = themeData.global.activeTheme;
  cursor = themeData.global.cursor;

  themePayload =
    themeId:
    let
      theme = themeData.themes.${themeId};
    in
    {
      id = themeId;
      inherit (theme) name description colors;
      fonts = {
        interface = themeData.global.fonts.interface.name;
        terminal = themeData.global.fonts.terminal.name;
        emoji = themeData.global.fonts.emoji.name;
      };
      ui = themeData.global.ui;
    };

  themeToLua = themeId: "return ${toLua (themePayload themeId)}\n";
  themeToJson = themeId: builtins.toJSON (themePayload themeId);

  themeToKitty =
    themeId:
    let
      theme = themeData.themes.${themeId};
      inherit (theme) colors;
      inherit (themeData.global) fonts ui;
    in
    ''
      font_family ${fonts.terminal.name}
      font_size ${toString ui.fontSize}

      foreground ${colors.text}
      background ${colors.background}

      cursor ${colors.accent}
      cursor_text_color ${colors.accentForeground}

      selection_foreground ${colors.text}
      selection_background ${colors.accentMuted}

      url_color ${colors.info}

      color0  ${colors.terminalBlack}
      color1  ${colors.terminalRed}
      color2  ${colors.terminalGreen}
      color3  ${colors.terminalYellow}
      color4  ${colors.terminalBlue}
      color5  ${colors.terminalMagenta}
      color6  ${colors.terminalCyan}
      color7  ${colors.terminalWhite}

      color8  ${colors.terminalBrightBlack}
      color9  ${colors.terminalBrightRed}
      color10 ${colors.terminalBrightGreen}
      color11 ${colors.terminalBrightYellow}
      color12 ${colors.terminalBrightBlue}
      color13 ${colors.terminalBrightMagenta}
      color14 ${colors.terminalBrightCyan}
      color15 ${colors.terminalBrightWhite}

      tab_bar_background ${colors.background}

      active_tab_foreground ${colors.accentForeground}
      active_tab_background ${colors.accent}

      inactive_tab_foreground ${colors.textSecondary}
      inactive_tab_background ${colors.surface}

      background_opacity ${toString ui.terminalOpacity}
    '';

  luaThemeFiles = lib.genAttrs themeNames (themeId: {
    text = themeToLua themeId;
    force = true;
  });

  jsonThemeFiles = lib.genAttrs themeNames (themeId: {
    text = themeToJson themeId;
    force = true;
  });

  kittyThemeFiles = lib.genAttrs themeNames (themeId: {
    text = themeToKitty themeId;
    force = true;
  });

  themeList = builtins.concatStringsSep "\n" (
    map (
      themeId:
      let
        theme = themeData.themes.${themeId};
      in
      "${themeId}\t${theme.name}"
    ) themeNames
  );

  generatedLuaFiles = lib.mapAttrs' (
    themeId: file: lib.nameValuePair "aurora/themes/${themeId}.lua" file
  ) luaThemeFiles;

  generatedJsonFiles = lib.mapAttrs' (
    themeId: file: lib.nameValuePair "aurora/themes/${themeId}.json" file
  ) jsonThemeFiles;

  generatedKittyFiles = lib.mapAttrs' (
    themeId: file: lib.nameValuePair "aurora/themes/${themeId}.kitty.conf" file
  ) kittyThemeFiles;

in
{
  xdg.configFile = {
    "aurora/themes.json" = {
      text = builtins.toJSON themeData;
      force = true;
    };
    "aurora/themes.list" = {
      text = themeList + "\n";
      force = true;
    };

    "environment.d/20-dark-theme.conf".text = lib.concatStrings (
      lib.mapAttrsToList (key: value: "${key}=${value}\n") env.gtkQt
    );

    "xdg-desktop-portal/portals.conf".text = ''
      [preferred]
      default=hyprland;gtk
      org.freedesktop.impl.portal.Settings=gtk
      org.freedesktop.impl.portal.FileChooser=gtk
      org.freedesktop.impl.portal.ScreenCast=hyprland
      org.freedesktop.impl.portal.Screenshot=hyprland
    '';

    "qt6ct/qt6ct.conf".text = ''
      [Appearance]
      color_scheme_path=${config.xdg.configHome}/qt6ct/colors/darker.conf
      custom_palette=true
      icon_theme=WhiteSur-dark
      standard_dialogs=xdgdesktopportal
      style=kvantum
    '';

    "qt6ct/colors/darker.conf".text = ''
      [ColorScheme]
      active_colors=#ffffffff, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ffffffff, #ffffffff, #ffffffff, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #fff9f9f9, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff
      disabled_colors=#ff808080, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ff808080, #ffffffff, #ff808080, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #ff808080, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff
      inactive_colors=#ffffffff, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ffffffff, #ffffffff, #ffffffff, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #fff9f9f9, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff
    '';

    "qt5ct/qt5ct.conf".text = ''
      [Appearance]
      color_scheme_path=${config.xdg.configHome}/qt5ct/colors/darker.conf
      custom_palette=true
      icon_theme=WhiteSur-dark
      standard_dialogs=xdgdesktopportal
      style=kvantum
    '';

    "qt5ct/colors/darker.conf".text = ''
      [ColorScheme]
      active_colors=#ffffffff, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ffffffff, #ffffffff, #ffffffff, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #fff9f9f9, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff
      disabled_colors=#ff808080, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ff808080, #ffffffff, #ff808080, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #ff808080, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff
      inactive_colors=#ffffffff, #ff424245, #ff979797, #ff5e5c5b, #ff302f2e, #ff4a4947, #ffffffff, #ffffffff, #ffffffff, #ff3d3d3d, #ff222020, #ffe7e4e0, #ff12608a, #fff9f9f9, #ff0986d3, #ffa70b06, #ff5c5b5a, #ffffffff, #ff3f3f36, #ffffffff, #80ffffff
    '';

    "fontconfig/conf.d/99-default-inter.conf".text = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <description>Inter as default UI sans</description>
        <alias binding="same">
          <family>sans-serif</family>
          <prefer>
            <family>Inter</family>
            <family>Excalifont</family>
            <family>DejaVu Sans</family>
          </prefer>
        </alias>
        <alias binding="same">
          <family>serif</family>
          <prefer>
            <family>Inter</family>
            <family>DejaVu Serif</family>
          </prefer>
        </alias>
      </fontconfig>
    '';
  }

  // generatedLuaFiles
  // generatedJsonFiles
  // generatedKittyFiles;

  gtk = {
    enable = true;
    theme = {
      name = "WhiteSur-Dark";
      package = pkgs.whitesur-gtk-theme;
    };
    iconTheme = {
      name = "WhiteSur-dark";
      package = pkgs.whitesur-icon-theme;
    };
    cursorTheme = {
      inherit (cursor) name;
      package = pkgs.apple-cursor;
      size = params.cursorSize;
    };
    font = {
      name = "Inter";
      size = 13;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-font-name = "Inter 13";
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-theme-name = "WhiteSur-Dark";
      gtk-font-name = "Inter 13";
    };
  };

  home.sessionVariables = env.gtkQt // {
    XCURSOR_THEME = cursor.name;
    XCURSOR_SIZE = toString params.cursorSize;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    gtk-theme = "WhiteSur-Dark";
    icon-theme = "WhiteSur-dark";
    cursor-theme = cursor.name;
    font-name = "Inter 13";
    document-font-name = "Inter 13";
  };

  home.activation.initializeAuroraTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    theme_dir="$HOME/.config/aurora"
    theme_file="$theme_dir/active-theme"
    active_lua="$theme_dir/active-theme.lua"
    active_kitty="$theme_dir/active-kitty.conf"
    default_theme="${defaultTheme}"

    mkdir -p "$theme_dir" "$HOME/.cache/aurora"
    printf '%s\n' "dark" > "$theme_dir/mode"
    if command -v gsettings >/dev/null 2>&1; then
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
      gsettings set org.gnome.desktop.interface gtk-theme WhiteSur-Dark >/dev/null 2>&1 || true
      gsettings set org.gnome.desktop.interface icon-theme WhiteSur-dark >/dev/null 2>&1 || true
      gsettings set org.gnome.desktop.interface cursor-theme ${cursor.name} >/dev/null 2>&1 || true
    fi

    if [ ! -f "$theme_file" ]; then
      printf '%s\n' "$default_theme" > "$theme_file"
    fi

    selected="$(cat "$theme_file")"

    if [[ ! -f "$theme_dir/themes/$selected.lua" ]]; then
      printf '%s\n' "$default_theme" > "$theme_file"
      selected="$default_theme"
    fi

    ln -sfn "$theme_dir/themes/$selected.lua" "$active_lua"

    if [[ -f "$theme_dir/themes/$selected.kitty.conf" ]]; then
      ln -sfn "$theme_dir/themes/$selected.kitty.conf" "$active_kitty"
    else
      ln -sfn "$theme_dir/themes/$default_theme.kitty.conf" "$active_kitty"
    fi
  '';

  home.file.".local/bin/aurora-theme" = {
    executable = true;

    text = ''
      #!/usr/bin/env bash

      set -euo pipefail

      CONFIG_DIR="$HOME/.config/aurora"
      THEMES_FILE="$CONFIG_DIR/themes.list"
      ACTIVE_THEME="$CONFIG_DIR/active-theme"
      ACTIVE_LUA="$CONFIG_DIR/active-theme.lua"
      ACTIVE_KITTY="$CONFIG_DIR/active-kitty.conf"
      THEME_DIR="$CONFIG_DIR/themes"

      if [[ ! -f "$THEMES_FILE" ]]; then
        echo "Aurora: theme list not found." >&2
        exit 1
      fi

      if [[ $# -gt 0 ]]; then
        selected="$1"
      else
        echo "Aurora: usage: aurora-theme <theme-id|display-name>" >&2
        echo "Aurora: for a picker, run: qs ipc call theme toggle" >&2
        exit 1
      fi

      [[ -z "$selected" ]] && exit 0

      theme_id="$(
        awk -F '\t' -v sel="$selected" '
          $1 == sel || $2 == sel {
            print $1
            exit
          }
        ' "$THEMES_FILE"
      )"

      if [[ -z "$theme_id" ]]; then
        echo "Aurora: unknown theme: $selected" >&2
        exit 1
      fi

      theme_lua="$THEME_DIR/$theme_id.lua"
      theme_json="$THEME_DIR/$theme_id.json"
      theme_kitty="$THEME_DIR/$theme_id.kitty.conf"

      if [[ ! -f "$theme_lua" ]]; then
        echo "Aurora: generated Lua theme not found: $theme_id" >&2
        exit 1
      fi

      if [[ ! -f "$theme_json" ]]; then
        echo "Aurora: generated JSON theme not found: $theme_id" >&2
        exit 1
      fi

      if [[ ! -f "$theme_kitty" ]]; then
        echo "Aurora: generated Kitty theme not found: $theme_id" >&2
        exit 1
      fi

      ln -sfn "$theme_lua" "$ACTIVE_LUA"
      ln -sfn "$theme_kitty" "$ACTIVE_KITTY"

      printf '%s\n' "$theme_id" > "$ACTIVE_THEME"

      if command -v hyprctl >/dev/null 2>&1; then
        hyprctl reload >/dev/null 2>&1 || true
      fi

      if command -v kitten >/dev/null 2>&1; then
        shopt -s nullglob

        kitty_sockets=(
          "$XDG_RUNTIME_DIR"/kitty-*
        )

        for socket in "''${kitty_sockets[@]}"; do
          [[ -S "$socket" ]] || continue

          kitten @ \
            --to "unix:$socket" \
            set-colors \
            --all \
            --configured \
            "$theme_kitty" \
            >/dev/null 2>&1 || true
        done
      fi

      AURORA_ZSH_REFRESH_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/aurora-zsh"

      if [[ -d "$AURORA_ZSH_REFRESH_DIR" ]]; then
        for fifo in "$AURORA_ZSH_REFRESH_DIR"/*; do
          [[ -p "$fifo" ]] || continue

          (
            printf '%s\n' "refresh" > "$fifo"
          ) >/dev/null 2>&1 &
        done
      fi

      # System dark preference for GTK / portals / Electron
      if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.interface color-scheme prefer-dark >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface gtk-theme WhiteSur-Dark >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface icon-theme WhiteSur-dark >/dev/null 2>&1 || true
        gsettings set org.gnome.desktop.interface cursor-theme macOS >/dev/null 2>&1 || true
      fi

      printf '%s\n' "dark" > "$CONFIG_DIR/mode"

      echo "Aurora theme: $selected"
    '';
  };
}
