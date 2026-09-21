{ lib, pkgs, ... }:

let
  seedIni = pkgs.writeText "insta360link.ini" ''
    [Device]
    LastDevice=/dev/video0

    [PTZ]
    PanStep=8
    TiltStep=8

    [Looks]
    Active=0

    [Preview]
    Width=1280
    Height=720

    [Presets]
    Name0=Stream Face
    Valid0=1
    Pan0=0
    Tilt0=-36000
    Zoom0=170
    Tracking0=1
    Frame0=0
    Mode0=0
    Name1=Stream Wide
    Valid1=1
    Pan1=0
    Tilt1=-18000
    Zoom1=110
    Tracking1=1
    Frame1=2
    Mode1=0
    Name2=Call
    Valid2=1
    Pan2=0
    Tilt2=-28800
    Zoom2=200
    Tracking2=1
    Frame2=0
    Mode2=0
    Name3=Desk
    Valid3=1
    Pan3=-57600
    Tilt3=-172800
    Zoom3=100
    Tracking3=0
    Frame3=1
    Mode3=1
  '';
in
{
  home.activation.seedInsta360Link = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.config/Insta360 Link Controller"
    mkdir -p "$dest"
    ini="$dest/insta360link.ini"

    if [ ! -f "$ini" ] || ! grep -q '^\[Looks\]' "$ini" 2>/dev/null; then
      cp ${seedIni} "$ini"
    fi
  '';
}
