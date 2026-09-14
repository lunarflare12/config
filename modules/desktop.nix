{
  lib,
  pkgs,
  params,
  ...
}:

let
  glyphSddmTheme = pkgs.stdenvNoCC.mkDerivation {
    pname = "sddm-glyph-theme";
    version = "1.0";
    src = ./sddm/glyph;
    dontBuild = true;
    dontFixup = true;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/sddm/themes/glyph
      cp -r . $out/share/sddm/themes/glyph/
      font=$(find ${pkgs.nerd-fonts.symbols-only} -name 'SymbolsNerdFont-Regular.ttf' | head -n 1)
      if [ -z "$font" ]; then
        echo "SymbolsNerdFont-Regular.ttf missing from nerd-fonts.symbols-only" >&2
        exit 1
      fi
      rm -f $out/share/sddm/themes/glyph/assets/fonts/SymbolsNerdFont.ttf
      cp "$font" $out/share/sddm/themes/glyph/assets/fonts/SymbolsNerdFont.ttf
      runHook postInstall
    '';
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      hyprlandPlugins = prev.hyprlandPlugins // {
        csgo-vulkan-fix = prev.hyprlandPlugins.csgo-vulkan-fix.overrideAttrs (old: {
          postPatch = (old.postPatch or "") + ''
            cp ${../home/dots/hypr/plugins/csgo-vulkan-fix/main.cpp} main.cpp
          '';
        });
      };
    })
  ];

  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.dconf.enable = true;
  security.pam.services.hyprlock = {};
  programs.thunar.enable = params.fileManager == "thunar";
  services.xserver.enable = lib.mkForce false;
  hardware.i2c.enable = true;
  hardware.bluetooth.enable = params.hardware.bluetooth or false;
  hardware.bluetooth.powerOnBoot = params.hardware.bluetooth or false;
  services.blueman.enable = params.hardware.bluetooth or false;

  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    sessionPackages = lib.mkForce [
      (pkgs.runCommand "hyprland-uwsm-session" {
        passthru.providedSessions = [ "hyprland-uwsm" ];
      } ''
        mkdir -p $out/share/wayland-sessions
        cp ${pkgs.hyprland}/share/wayland-sessions/hyprland-uwsm.desktop $out/share/wayland-sessions/
      '')
    ];
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "glyph";
      package = pkgs.kdePackages.sddm;
      extraPackages = [
        glyphSddmTheme
        pkgs.kdePackages.breeze
        pkgs.kdePackages.qtdeclarative
        pkgs.kdePackages.qtsvg
        pkgs.kdePackages.qt5compat
      ];
      wayland.compositor = "kwin";
      settings = {
        General.GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell,XCURSOR_THEME=breeze_cursors,XCURSOR_SIZE=${toString params.cursorSize},KWIN_FORCE_SW_CURSOR=1";
        Theme = {
          CursorTheme = "breeze_cursors";
          CursorSize = toString params.cursorSize;
        };
      };
    };
  };

  environment.systemPackages = [
    glyphSddmTheme
    pkgs.kdePackages.breeze
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
    config = {
      common = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      };
      hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
        "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
      };
    };
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.extraConfig."51-audio-priority" = {
      "monitor.alsa.rules" = [
        {
          matches = [
            { "node.name" = "~alsa_output.usb-Fifine_.*"; }
          ];
          actions.update-props."node.disabled" = true;
        }
        {
          matches = [
            { "node.name" = "~alsa_output.pci-.*analog-stereo"; }
          ];
          actions.update-props = {
            "priority.driver" = 1500;
            "priority.session" = 1500;
          };
        }
      ];
    };
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
    inter
    noto-fonts-color-emoji
  ];

  users.users = lib.mapAttrs (_: _: {
    extraGroups = [
      "input"
      "i2c"
    ];
  }) params.users;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
    GTK_THEME = "Adwaita:dark";
    GTK_APPLICATION_PREFER_DARK_THEME = "1";
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QT_STYLE_OVERRIDE = "kvantum";
    ADW_DEBUG_COLOR_SCHEME = "prefer-dark";
  };
}
