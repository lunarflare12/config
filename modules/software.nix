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

  virtualisation.oci-containers = lib.mkIf (host.enabled "whisper") {
    backend = "docker";
    containers.whisper = {
      image = "onerahmet/openai-whisper-asr-webservice:latest-gpu";
      autoStart = true;
      ports = [ "127.0.0.1:9000:9000" ];
      environment = {
        ASR_MODEL = "small";
        ASR_ENGINE = "faster_whisper";
      };
      volumes = [ "whisper-cache:/root/.cache" ];
      extraOptions = [ "--device=nvidia.com/gpu=all" ];
    };
  };

  environment.systemPackages = (map (host.resolve pkgs) params.packages) ++ [
    pkgs.insta360-link-controller
    pkgs.bubblewrap
    pkgs.xdg-dbus-proxy
  ];

  services.udev.packages = [ pkgs.insta360-link-controller ];

  # Keep Insta360 Link awake — autosuspend makes first open after idle very slow.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="2e1a", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    ACTION=="add", SUBSYSTEM=="usb", ATTRS{idVendor}=="2e1a", TEST=="power/control", ATTR{power/control}="on"
  '';
}
