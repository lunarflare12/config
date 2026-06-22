{ accounts, programs, wm, wmTypes }:
{ lib, pkgs, ... }:
let
  niriEnabled = wm == wmTypes.niri;

  steam =
    if programs.steam == true then
      {
        enable = true;
        libraryDir = "/games";
      }
    else
      programs.steam or { enable = false; };

  steamEnabled = steam.enable or false;
  libraryDir = steam.libraryDir or "/games";
  steamDir = "${libraryDir}/Steam";
  owners = map (account: account.name) accounts;
in {
  programs.niri.enable = lib.mkIf niriEnabled true;

  security.polkit.enable = lib.mkIf niriEnabled true;
  services.udisks2.enable = lib.mkIf niriEnabled true;

  xdg.portal.extraPortals = lib.mkIf niriEnabled [
    pkgs.xdg-desktop-portal-gtk
  ];

  programs.gamemode.enable = lib.mkIf steamEnabled true;

  networking.wireguard.enable = lib.mkIf (programs.wireguard or false) true;

  environment.systemPackages = lib.mkIf (programs.wireguard or false) [
    pkgs.wireguard-tools
  ];

  programs.steam = lib.mkIf steamEnabled {
    enable = true;
    extest.enable = true;
    protontricks.enable = true;
    remotePlay.openFirewall = true;
    localNetworkGameTransfers.openFirewall = true;
    extraPackages = with pkgs; [
      gamescope
    ];
  };

  systemd.tmpfiles.rules = lib.mkIf steamEnabled (
    map
      (owner: "d ${steamDir} 0755 ${owner} users -")
      owners
  );
}
