{
  initSys,
  initSysTypes,
  wm,
  wmTypes,
  wmConfig,
  user,
  hostname,
  session ? { },
}:
{ lib, pkgs, ... }:
let
  sddmEnabled = initSys == initSysTypes.sddm;
  niriWm = wm == wmTypes.niri;

  sess =
    {
      id = "${user}-niri";
      label = "Niri";
      comment = "Wayland (niri)";
      desktopNames = "niri";
    }
    // session;

  modeBase = builtins.head (lib.splitString "@" wmConfig.mode);
  modeParts = lib.splitString "x" modeBase;
  screenWidth = lib.elemAt modeParts 0;
  screenHeight = lib.elemAt modeParts 1;

  kwinCompositorCommand = lib.concatStringsSep " " [
    "${lib.getBin pkgs.kdePackages.kwin}/bin/kwin_wayland"
    "--no-global-shortcuts"
    "--no-kactivities"
    "--no-lockscreen"
    "--locale1"
    "--width"
    screenWidth
    "--height"
    screenHeight
  ];

  sddmTheme = pkgs.where-is-my-sddm-theme.override {
    themeConfig.General = {
      passwordCharacter = "*";
      background = "";
      backgroundFill = "#000000";
      backgroundFillMode = "aspect";
      cursorColor = "#ffffff";
    };
  };

  niriSession = pkgs.writeShellScriptBin "${user}-niri-session" ''
    unset DISPLAY WAYLAND_DISPLAY WAYLAND_SOCKET XAUTHORITY
    export XDG_SESSION_TYPE=wayland
    cd "''${HOME:-/}"
    export PATH="$HOME/.local/bin:/run/wrappers/bin:/run/current-system/sw/bin:$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$PATH"
    ${pkgs.systemd}/bin/systemctl --user stop niri.service 2>/dev/null || true
    ${pkgs.systemd}/bin/systemctl --user reset-failed 2>/dev/null || true
    exec ${pkgs.niri}/bin/niri-session
  '';

  niriDesktop = pkgs.runCommand "${hostname}-${sess.id}-wayland-desktop" {
    passthru.providedSessions = [ sess.id ];
  } ''
    mkdir -p $out/share/wayland-sessions
    {
      echo '[Desktop Entry]'
      echo 'Name=${sess.label}'
      echo 'Comment=${sess.comment}'
      echo "Exec=${niriSession}/bin/${user}-niri-session"
      echo 'Type=Application'
      echo 'DesktopNames=${sess.desktopNames}'
    } > $out/share/wayland-sessions/${sess.id}.desktop
  '';
in
lib.mkIf sddmEnabled {
  assertions = [
    {
      assertion = niriWm;
      message = "initSys.type.sddm currently requires wm.type.niri";
    }
  ];

  qt.enable = true;

  xdg.portal.enable = true;

  services.displayManager = {
    defaultSession = sess.id;
    sessionPackages = [ niriDesktop ];

    sddm = {
      enable = true;
      theme = "where_is_my_sddm_theme";
      extraPackages = [ sddmTheme ];
      wayland = {
        enable = true;
        compositor = "kwin";
      };
      settings = {
        General = {
          DisplayServer = "wayland";
          GreeterEnvironment = "QT_WAYLAND_SHELL_INTEGRATION=layer-shell";
        };
        Wayland = {
          CompositorCommand = kwinCompositorCommand;
        };
      };
    };
  };

  environment.systemPackages = [
    pkgs.xwayland-satellite
    sddmTheme
  ];

  environment.etc.issue.text = ''
    NixOS — SDDM (Wayland). TTY: Ctrl+Alt+F1–F6.
  '';
}
