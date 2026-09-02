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
      runHook postInstall
    '';
  };
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.dconf.enable = true;
  programs.thunar.enable = params.fileManager == "thunar";
  services.xserver.enable = lib.mkForce false;
  hardware.bluetooth.enable = params.hardware.bluetooth or false;
  services.blueman.enable = params.hardware.bluetooth or false;

  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "glyph";
      package = pkgs.kdePackages.sddm;
      extraPackages = [
        glyphSddmTheme
        pkgs.kdePackages.qtdeclarative
        pkgs.kdePackages.qtsvg
        pkgs.kdePackages.qt5compat
      ];
      settings.Theme = {
        Current = "glyph";
        ThemeDir = "${glyphSddmTheme}/share/sddm/themes";
        CursorTheme = "breeze_cursors";
      };
    };
  };

  environment.systemPackages = [
    glyphSddmTheme
    pkgs.kdePackages.breeze
  ];

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];

  users.users = lib.mapAttrs (_: _: {
    extraGroups = [ "input" ];
  }) params.users;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
  };
}
