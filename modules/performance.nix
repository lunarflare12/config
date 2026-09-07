{ ... }:

{
  nix.settings = {
    auto-optimise-store = true;
    download-buffer-size = 268435456;
    warn-dirty = false;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
    persistent = true;
  };

  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  boot.loader.systemd-boot.configurationLimit = 8;
  boot.tmp.cleanOnBoot = true;

  documentation.nixos.enable = false;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  programs.command-not-found.enable = false;

  powerManagement.cpuFreqGovernor = "performance";

  services.irqbalance.enable = true;

  services.journald.extraConfig = ''
    SystemMaxUse=500M
    MaxRetentionSec=14day
  '';

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.vfs_cache_pressure" = 50;
  };
}
