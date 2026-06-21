{ config }: {
  hardware = config.myHomePC;
  hostName = "ddHomePC";
  timeZone = "Europe/Minsk";
  stateVersion = "26.05";

  module = { pkgs, ... }: {
    programs.zsh.enable = true;

    users.users.dd = {
      isNormalUser = true;
      shell = pkgs.zsh;
      extraGroups = [ "wheel" ];
      packages = with pkgs; [ tree ];
    };
  };
}
