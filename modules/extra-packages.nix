{ lib, pkgs, params, ... }:

let
  packages = params.packages or [ ];
  has = name: lib.elem name packages;
in
{
  # packages.nix is root-owned and only maps a fixed attrset.
  # Keep new packages here so the flake stays writable.
  environment.systemPackages =
    [
      pkgs.dmidecode
      pkgs.lshw
    ]
    ++ lib.optional (has "vlc") pkgs.vlc
    ++ lib.optional (has "vagrant") pkgs.vagrant
    ++ lib.optional (has "discord") pkgs.discord
    ++ lib.optional (has "spotify") pkgs.spotify
    ++ lib.optional (has "xournalpp") pkgs.xournalpp;
}
