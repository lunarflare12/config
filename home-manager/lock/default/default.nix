{ pkgs, lib, ... }:
let
  swaylockConfig = ''
    color=000000
    ignore-empty-password
    show-failed-attempts
    disable-caps-lock-text
    indicator-idle-visible

    indicator-radius=120
    indicator-thickness=8
    ring-color=ffffff
    ring-clear-color=cccccc
    ring-ver-color=33cc33
    ring-wrong-color=ff3117
    inside-color=000000
    inside-clear-color=111111
    inside-ver-color=111111
    inside-wrong-color=331111
    line-color=ffffff
    line-clear-color=cccccc
    line-ver-color=33cc33
    line-wrong-color=ff3117
    key-hl-color=ffffff
    bs-hl-color=ffffff
    text-color=ffffff
    separator-color=ffffff
    layout-bg-color=000000
    layout-text-color=ffffff

    font=JetBrains Mono
    font-size=48
  '';

  swaylockRun = pkgs.writeShellApplication {
    name = "swaylock-run";
    runtimeInputs = [ pkgs.swaylock ];
    text = ''
      exec swaylock
    '';
  };
in
{
  home.packages = [
    pkgs.swaylock
    pkgs.xss-lock
    pkgs.jetbrains-mono
    swaylockRun
  ];

  xdg.configFile."swaylock/config".text = swaylockConfig;

  systemd.user.services.xss-lock = {
    Unit = {
      Description = "Lock screen on demand (swaylock, SDDM-style)";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${lib.getExe pkgs.xss-lock} -- ${lib.getExe swaylockRun}";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
