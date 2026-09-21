{ lib, ... }:

{
  boot = {
    loader.systemd-boot.configurationLimit = 8;
    loader.timeout = 1;
    tmp.cleanOnBoot = true;
    kernelParams = [ "nowatchdog" ];
  };

  environment.defaultPackages = lib.mkForce [ ];

  documentation = {
    nixos.enable = false;
    doc.enable = false;
    info.enable = false;
    man.enable = false;
    man.cache.enable = false;
  };

  programs = {
    command-not-found.enable = false;
    nano.enable = false;
  };

  networking.networkmanager.unmanaged = [
    "type:wifi"
    "type:wwan"
  ];

  virtualisation.docker.enableOnBoot = false;
  powerManagement.cpuFreqGovernor = "performance";

  services = {
    speechd.enable = false;
    fstrim.enable = true;
    irqbalance.enable = false;
    journald.extraConfig = ''
      SystemMaxUse=200M
      MaxRetentionSec=7day
      SystemMaxFileSize=50M
    '';
  };

  systemd = {
    services = {
      ModemManager.enable = lib.mkForce false;
      wpa_supplicant.enable = lib.mkForce false;
      NetworkManager-wait-online.enable = false;
    };
    coredump.settings.Coredump = {
      Storage = "none";
      ProcessSizeMax = "0";
    };
    tmpfiles.rules = [
      "d /var/lib/systemd/coredump 0755 root root 1d"
    ];
  };
}
