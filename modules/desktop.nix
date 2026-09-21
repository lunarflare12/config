{
  lib,
  pkgs,
  params,
  host,
  desktopEnv,
  ...
}:

let
  portal = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
    "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
    "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
    "org.freedesktop.impl.portal.Settings" = [ "gtk" ];
  };
  symbolsNerdFont = "${pkgs.nerd-fonts.symbols-only}/share/fonts/truetype/NerdFonts/Symbols/SymbolsNerdFont-Regular.ttf";
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
      install -Dm644 ${symbolsNerdFont} $out/share/sddm/themes/glyph/assets/fonts/SymbolsNerdFont.ttf
      runHook postInstall
    '';
  };
in
{
  programs = {
    hyprland = {
      enable = true;
      withUWSM = true;
      xwayland.enable = true;
    };
    dconf.enable = true;
    thunar = {
      enable = params.fileManager == "thunar";
      plugins = [
        pkgs.thunar-archive-plugin
        pkgs.thunar-volman
        pkgs.thunar-media-tags-plugin
      ];
    };
  };

  services.tumbler.enable = true;

  security = {
    pam.services.hyprlock = { };
    rtkit.enable = true;
  };

  hardware = {
    i2c.enable = true;
    bluetooth = {
      enable = host.enabled "bluetooth";
      powerOnBoot = host.enabled "bluetooth";
    };
  };

  services = {
    gvfs.enable = true;
    xserver.enable = lib.mkForce false;
    blueman.enable = host.enabled "bluetooth";
    displayManager = {
      defaultSession = "hyprland-uwsm";
      sessionPackages = lib.mkForce [
        (pkgs.runCommand "hyprland-uwsm-session"
          {
            passthru.providedSessions = [ "hyprland-uwsm" ];
          }
          ''
            mkdir -p $out/share/wayland-sessions
            cp ${pkgs.hyprland}/share/wayland-sessions/hyprland-uwsm.desktop $out/share/wayland-sessions/
          ''
        )
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
    pipewire = {
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
  };

  environment = {
    systemPackages = [
      glyphSddmTheme
      pkgs.kdePackages.breeze
    ];
    sessionVariables = desktopEnv.wayland // desktopEnv.gtkQt;
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
    ];
    config = {
      common = portal;
      hyprland = portal;
    };
  };

  fonts = {
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      inter
      noto-fonts-color-emoji
      excalifont
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [
          "Excalifont"
          "Inter"
        ];
        sansSerif = [
          "Excalifont"
          "Inter"
        ];
        monospace = [ "JetBrainsMono Nerd Font Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
