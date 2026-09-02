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

  terminal = global.terminals.alacritty;
  browser = global.browsers.firefox;
  fileManager = global.fileManagers.thunar;

  vms = with global.vms; [
    libvirt
    virt-manager
  ];

  monitors = [
    {
      output = "";
      mode = "highrr";
      position = "auto";
      scale = 1;
    }
  ];

  input = {
    kbLayout = "us";
    sensitivity = 0;
    naturalScroll = false;
  };

  cursorSize = 24;
}
