{ pkgs, ... }:
let
  nikaidoHiro = pkgs.callPackage ../../../shared/pkgs/nikaido-hiro-xcursor.nix { };
in
{
  home.pointerCursor = {
    name = "nikaido-hiro";
    package = nikaidoHiro;
    size = 48;
    gtk.enable = true;
    x11.enable = false;
  };

  home.sessionVariables = {
    XCURSOR_THEME = "nikaido-hiro";
    XCURSOR_SIZE = "48";
  };
}
