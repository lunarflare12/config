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
  homeManager = with homeManagerModules; [
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
    steam = true;
  };
}
