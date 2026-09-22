{
  systemArch = "x86_64-linux";
  stateVersion = "26.05";
  userName = "dd";
  # Git checkout of this flake, relative to $HOME. Hypr/QS/scripts are
  # live-linked here so edits apply without copying into the Nix store.
  repo = "projects/config";

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
  browser = "google-chrome";
  fileManager = "thunar";
  cursorSize = 24;

  features = {
    docker = true;
    steam = true;
    libvirt = true;
    virt-manager = true;
    bluetooth = false;
    battery = false;
    whisper = true;
  };

  packages = [
    "terraform"
    "ansible"
    "go"
    "nodejs_latest"
    "claude-code"
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
    "openlens"
    "awscli2"
    "btop"
    "vagrant"
    "vlc"
    "xournalpp"
    "prismlauncher"
    "libreoffice-stable"
  ];

  monitors = [
    {
      output = "DP-1";
      mode = "2560x1080@200.00Hz";
      position = "0x0";
      scale = 1;
      bitdepth = 8;
    }
    {
      output = "HDMI-A-1";
      mode = "1920x1080@60.00Hz";
      position = "2560x0";
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
