{ lib, pkgs, params, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = false;
  };

  programs.xwayland.enable = lib.mkForce false;
  programs.dconf.enable = true;
  programs.thunar.enable = params.fileManager == "thunar";
  services.xserver.enable = lib.mkForce false;
  services.blueman.enable = true;
  services.power-profiles-daemon.enable = true;

  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    sddm = {
      enable = true;
      wayland.enable = true;
    };
  };

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
    SDL_VIDEODRIVER = "wayland";
  };
}
