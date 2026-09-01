{
  lib,
  pkgs,
  ...
}:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = false;
  };

  programs.xwayland.enable = lib.mkForce false;
  programs.dconf.enable = true;

  # SDDM/Hyprland run on Wayland. Do not start Xorg.
  # `services.xserver.videoDrivers` in nvidia.nix only selects the GPU driver.
  services.xserver.enable = lib.mkForce false;

  services.displayManager = {
    defaultSession = "hyprland-uwsm";
    sddm = {
      enable = true;
      wayland = {
        enable = true;
        compositor = "weston";
      };
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

  programs.firefox.enable = true;

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
    CLUTTER_BACKEND = "wayland";
    TERMINAL = "alacritty";
  };

  environment.systemPackages = with pkgs; [
    alacritty
    (writeShellScriptBin "kitty" ''
      exec ${lib.getExe alacritty} "$@"
    '')
    wofi
    waybar
    wl-clipboard
    grim
    slurp
    hyprpicker
    hyprshot
  ];
}
