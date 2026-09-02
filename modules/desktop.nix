{
  lib,
  pkgs,
  params,
  ...
}:

let
  hyprlandConf = pkgs.writeText "hyprland.conf" ''
    $terminal = ${params.terminal}
    $browser = ${params.browser}
    $menu = wofi --show drun

    monitor=,preferred,auto,1
    exec-once = waybar

    bind = SUPER, Q, exec, $terminal
    bind = SUPER, B, exec, $browser
    bind = SUPER, R, exec, $menu
    bind = SUPER, C, killactive
    bind = SUPER, M, exit
    bind = SUPER, V, togglefloating
    bind = SUPER, F, fullscreen

    bind = SUPER, left, movefocus, l
    bind = SUPER, right, movefocus, r
    bind = SUPER, up, movefocus, u
    bind = SUPER, down, movefocus, d

    bind = SUPER, 1, workspace, 1
    bind = SUPER, 2, workspace, 2
    bind = SUPER, 3, workspace, 3
    bind = SUPER, 4, workspace, 4
    bind = SUPER, 5, workspace, 5

    bind = SUPER SHIFT, 1, movetoworkspace, 1
    bind = SUPER SHIFT, 2, movetoworkspace, 2
    bind = SUPER SHIFT, 3, movetoworkspace, 3
    bind = SUPER SHIFT, 4, movetoworkspace, 4
    bind = SUPER SHIFT, 5, movetoworkspace, 5

    bindm = SUPER, mouse:272, movewindow
    bindm = SUPER, mouse:273, resizewindow
  '';
in
{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
    xwayland.enable = false;
  };

  programs.xwayland.enable = lib.mkForce false;
  programs.dconf.enable = true;
  services.xserver.enable = lib.mkForce false;

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

  system.activationScripts.hyprlandUserConfig.text = lib.concatMapStrings (name: ''
    install -d -m 0755 -o ${name} -g users /home/${name}/.config/hypr
    if [ ! -e /home/${name}/.config/hypr/hyprland.conf ]; then
      install -m 0644 -o ${name} -g users ${hyprlandConf} /home/${name}/.config/hypr/hyprland.conf
    fi
  '') (lib.attrNames params.users);

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    MOZ_ENABLE_WAYLAND = "1";
    QT_QPA_PLATFORM = "wayland";
    GDK_BACKEND = "wayland";
    SDL_VIDEODRIVER = "wayland";
  };

  environment.systemPackages = with pkgs; [
    wofi
    waybar
    wl-clipboard
    grim
    slurp
  ];
}
