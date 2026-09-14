global:

{
  systemArch = "x86_64-linux";
  stateVersion = "26.05";

  users = {
    dd = {
      description = "DD";
      extraGroups = [
        "wheel"
        "networkmanager"
      ];
    };
  };

  terminal = global.terminals.kitty;
  browser = global.browsers.firefox;
  fileManager = global.fileManagers.thunar;

  vms = with global.vms; [
    libvirt
    virt-manager
  ];

  packages = with global.packages; [
    docker
    steam
    terraform
    ansible
    go
    node
    python
    telegram
    idea
    vscode
    cursor
    keymapp
    obsidian
    google-chrome
    kubectl
    k9s
    awscli2
    btop
    vagrant
    vlc
    discord
    spotify
    xournalpp
  ];

  hardware = {
    bluetooth = false;
    battery = false;
  };

  monitors = [
    {
      output = "HDMI-A-1";
      mode = "1920x1080@60.00Hz";
      # Left screen at the layout origin. Negative X was crashing Hyprland 0.56
      # on NVIDIA (pixman invalid damage, SIGSEGV). Gamescope pins Overwatch
      # to DP-1 by name, so XWayland origin no longer has to be the ultrawide.
      position = "0x0";
      scale = 1;
      bitdepth = 8;
    }
    {
      output = "DP-1";
      mode = "2560x1080@200.00Hz";
      position = "1920x0";
      scale = 1;
      bitdepth = 8;
    }
  ];

  input = {
    kbLayout = "us,ru";
    sensitivity = 0;
    naturalScroll = false;
  };

  cursorSize = 24;
}
