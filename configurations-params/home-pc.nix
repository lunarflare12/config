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
}
