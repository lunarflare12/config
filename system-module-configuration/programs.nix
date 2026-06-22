programs:
{ lib, pkgs, ... }: {
  programs.niri.enable = lib.mkIf (programs.niri or false) true;

  security.polkit.enable = lib.mkIf (programs.niri or false) true;

  networking.wireguard.enable = lib.mkIf (programs.wireguard or false) true;

  environment.systemPackages = lib.mkIf (programs.wireguard or false) [
    pkgs.wireguard-tools
  ];

  programs.steam = lib.mkIf (programs.steam or false) {
    enable = true;
  };
}
