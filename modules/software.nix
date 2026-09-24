{
  lib,
  pkgs,
  params,
  host,
  ...
}:

let
  insta360Wake = pkgs.writeShellApplication {
    name = "insta360-wake";
    text = ''
      for d in /sys/bus/usb/devices/*; do
        [[ -f "$d/idVendor" ]] || continue
        [[ "$(cat "$d/idVendor" 2>/dev/null || true)" == "2e1a" ]] || continue
        echo on > "$d/power/control"
        echo -1 > "$d/power/autosuspend"
        [[ -f "$d/power/autosuspend_delay_ms" ]] && echo -1 > "$d/power/autosuspend_delay_ms" || true
      done
    '';
  };
in
{
  hardware.keyboard.zsa.enable = lib.elem "keymapp" params.packages;
  programs.wireshark = lib.mkIf (lib.elem "wireshark" params.packages) {
    enable = true;
    package = pkgs.wireshark;
  };
  virtualisation.docker = lib.mkIf (host.enabled "docker") {
    enable = true;
    daemon.settings.features.cdi = true;
  };

  virtualisation.oci-containers = lib.mkIf (host.enabled "whisper") {
    backend = "docker";
    containers.whisper = {
      image = "onerahmet/openai-whisper-asr-webservice:latest-gpu";
      autoStart = false;
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
    insta360Wake
  ];

  services.udev.packages = [ pkgs.insta360-link-controller ];

  # Do not force uvcvideo quirks=0x200: that is RESTRICT_FRAME_RATE and
  # replaces the device table. uvcvideo still calls usb_enable_autosuspend()
  # after udev add, so ATTR on add is overwritten. Re-apply on bind + a
  # timer; otherwise the Link 2 parks in ~2s and Discord waits ~30s.
  services.udev.extraRules = ''
    ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2e1a", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    ACTION=="bind", DRIVER=="uvcvideo", ATTRS{idVendor}=="2e1a", RUN+="${pkgs.bash}/bin/sh -c '${pkgs.coreutils}/bin/echo on > /sys%p/../power/control; ${pkgs.coreutils}/bin/echo -1 > /sys%p/../power/autosuspend'"
    # Internal system disk is already "File System" in Thunar. NVMe has no
    # ID_BUS, so match the GPT autodetect flag systemd sets on the root disk.
    SUBSYSTEM=="block", ENV{DEVTYPE}=="disk", ENV{ID_PART_GPT_AUTO_ROOT_DISK}=="1", ENV{UDISKS_IGNORE}="1"
  '';

  systemd.services.insta360-wake = {
    description = "Keep Insta360 Link out of USB autosuspend";
    after = [ "systemd-udev-settle.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe insta360Wake;
    };
  };
  systemd.timers.insta360-wake = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "3s";
      OnUnitActiveSec = "15s";
      AccuracySec = "2s";
      Persistent = true;
    };
  };
  powerManagement.resumeCommands = ''
    ${lib.getExe insta360Wake} || true
  '';

  security.sudo.extraRules = [
    {
      users = [ host.userName ];
      commands = [
        {
          command = lib.getExe insta360Wake;
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
