{ lib, host, ... }:

{
  nix = {
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      download-buffer-size = 268435456;
      warn-dirty = false;
      min-free = 2147483648;
      max-free = 10737418240;
      max-jobs = "auto";
      cores = 0;
      http-connections = 64;
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
      persistent = true;
    };
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  programs.gamemode.settings.custom = lib.mkForce {
    start = "/home/${host.userName}/.config/scripts/gamemode-start.sh";
    end = "/home/${host.userName}/.config/scripts/gamemode-end.sh";
  };
}
