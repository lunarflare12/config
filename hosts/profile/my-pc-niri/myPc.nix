{ hardware, shared, homeManagerModules }: {
  hardwareProfile = hardware.homePc;
  kernel = shared.kernels."7.0.11";
  nvidiaDriver = shared.drivers."610.43.02";
  hostname = "ddHomePC";
  timezone = "Europe/Minsk";
  stateVersion = "26.05";
  buildLabel = "linux-7.0.11-nvidia-610.43.02";
  accounts = [ shared.accounts.dd ];
  graphics = {
    xserver = false;
    wayland = true;
  };
  wm = shared.wm.type.niri;
  wmConfig = {
    output = "DP-4";
    mode = "2560x1080@200.000";
    scale = 1;
  };
  initSys = shared.initSys.type.sddm;
  audio = {
    enable = true;
    pulse = true;
    alsa = true;
    alsa32 = true;
  };
  homeManager = with homeManagerModules; [
    niri
    cursors
    wallpaper
    swayosd
    swaync
    lock
    wlogout
    focus-urgent
    restore-workspaces
    cursor
    audio
    idea
    zen-browser
    steam
    zsh
    git
    kitty
    tmux
    ranger
    waybar
    k9s
  ];
  programs = {
    wireguard = true;
    steam = {
      enable = true;
      libraryDir = "/games";
    };
  };
}
