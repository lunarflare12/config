# RAM: zram first, disk swap as overflow. Game RAM caps live in launch scripts.
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 40;
    priority = 100;
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 30;
    "vm.page-cluster" = 0;
    "vm.vfs_cache_pressure" = 50;
    "vm.dirty_background_bytes" = 67108864;
    "vm.dirty_bytes" = 268435456;
    "vm.dirty_expire_centisecs" = 1500;
    "vm.dirty_writeback_centisecs" = 100;
    "vm.max_map_count" = 1048576;
    "kernel.split_lock_mitigate" = 0;
  };

  systemd.oomd = {
    enable = true;
    enableRootSlice = true;
    enableSystemSlice = true;
    enableUserSlices = true;
  };
}
