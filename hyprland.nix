{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = true;
  };

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${lib.getExe pkgs.tuigreet} --time --remember --asterisks --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions --cmd uwsm start hyprland-uwsm.desktop";
      user = "greeter";
    };
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
