{ lib, params, ... }:

let
  user = lib.head (lib.attrNames params.users);
in
{
  nix.settings = {
    auto-optimise-store = true;
    download-buffer-size = 268435456;
    warn-dirty = false;
    # Auto-GC when the store fills the disk instead of waiting for the weekly timer.
    min-free = 2147483648;
    max-free = 10737418240;
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
  boot.loader.timeout = 1;
  boot.tmp.cleanOnBoot = true;

  environment.defaultPackages = lib.mkForce [ ];

  documentation.nixos.enable = false;
  documentation.doc.enable = false;
  documentation.info.enable = false;
  documentation.man.enable = false;
  documentation.man.cache.enable = false;
  programs.command-not-found.enable = false;
  programs.nano.enable = false;
  services.speechd.enable = false;
  services.fstrim.enable = true;

  # Wired desktop: leave NM's internal wireless.enable flag alone (it
  # conflicts if forced off), but don't run the idle Wi-Fi/WWAN daemons.
  networking.networkmanager.unmanaged = [
    "type:wifi"
    "type:wwan"
  ];
  systemd.services.ModemManager.enable = lib.mkForce false;
  systemd.services.wpa_supplicant.enable = lib.mkForce false;
  systemd.services.NetworkManager-wait-online.enable = false;

  # irqbalance on a desktop Ryzen + NVIDIA fights the kernel's affinity
  # and costs a always-on daemon for no gain.
  services.irqbalance.enable = false;

  # Don't keep a 170MB dockerd when there are zero containers.
  # enableOnBoot=false still leaves docker.socket in sockets.target.
  virtualisation.docker.enableOnBoot = false;
  systemd.sockets.docker.wantedBy = lib.mkForce [ ];

  programs.gamemode.settings.custom = lib.mkForce {
    start = "/home/${user}/.config/scripts/gamemode-start.sh";
    end = "/home/${user}/.config/scripts/gamemode-end.sh";
  };

  powerManagement.cpuFreqGovernor = "performance";

  services.journald.extraConfig = ''
    SystemMaxUse=200M
    MaxRetentionSec=7day
    SystemMaxFileSize=50M
  '';

  # Cursor/Electron SIGTRAPs filled 1.3G of dumps. Keep the journal, skip cores.
  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = "0";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/systemd/coredump 0755 root root 1d"
  ];

  boot.kernelParams = [
    "nowatchdog"
  ];

  # Compress RAM instead of dumping Proton spikes onto the 16G disk swap.
  # Disk swap stays as overflow; zram has higher priority.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 40;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 30;
    "vm.vfs_cache_pressure" = 50;
    "vm.page-cluster" = 0;
    # Default dirty_ratio=20 is ~6G on 32G RAM. A cheap NVMe then stalls
    # the compositor for seconds while jbd2 flushes Steam overlay writes.
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_expire_centisecs" = 1500;
    "vm.dirty_writeback_centisecs" = 100;
    # Proton/Wine map a lot of address space; the default 65530 throttles it.
    "vm.max_map_count" = 1048576;
    "kernel.split_lock_mitigate" = 0;
  };
}
