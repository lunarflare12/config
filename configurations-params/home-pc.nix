global:

{
  systemArch = "x86_64-linux";

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

  vms = with global.vms; [
    libvirt
    virt-manager
  ];
}
