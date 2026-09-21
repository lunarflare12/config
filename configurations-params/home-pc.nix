{
  systemArch = "x86_64-linux";
  stateVersion = "26.05";
  userName = "dd";

  users = {
    dd = {
      description = "DD";
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
      ];
    };
  };

  terminal = "kitty";
  browser = "firefox";
  fileManager = "thunar";
  cursorSize = 24;

  features = {
    docker = true;
    steam = true;
    libvirt = true;
    virt-manager = true;
    bluetooth = false;
    battery = false;
    ollama = true;
  };

  packages = [
    "terraform"
    "ansible"
    "go"
    "nodejs_latest"
    "python3"
    "ffmpeg"
    "telegram-desktop"
    "jetbrains.idea-oss"
    "vscode"
    "code-cursor"
    "keymapp"
    "obsidian"
    "kubectl"
    "k9s"
    "awscli2"
    "btop"
    "vagrant"
    "vlc"
    "spotify"
    "xournalpp"
    "prismlauncher"
    "libreoffice-stable"
  ];

  monitors = [
    {
      output = "HDMI-A-1";
      mode = "1920x1080@60.00Hz";
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

  git = {
    userName = "lunarflare";
    userEmail = "tes@gmail.com";
  };
}
