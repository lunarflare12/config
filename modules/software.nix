{
  lib,
  pkgs,
  params,
  host,
  ...
}:

{
  hardware.keyboard.zsa.enable = lib.elem "keymapp" params.packages;
  virtualisation.docker = lib.mkIf (host.enabled "docker") {
    enable = true;
    daemon.settings.features.cdi = true;
  };

  services.ollama = lib.mkIf (host.enabled "ollama") {
    enable = true;
    acceleration = "cuda";
    host = "127.0.0.1";
  };

  environment.systemPackages = (map (host.resolve pkgs) params.packages) ++ [
    pkgs.insta360-link-controller
    pkgs.bubblewrap
    pkgs.xdg-dbus-proxy
  ];

  services.udev.packages = [ pkgs.insta360-link-controller ];
}
