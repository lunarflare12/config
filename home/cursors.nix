{
  lib,
  pkgs,
  ...
}:

# Extra cursor packs. Default pointer stays apple-cursor / macOS in default.nix.
# Packs live in pkgs.aurora-cursors and are linked into the usual icon dirs so
# hyprctl setcursor and set-cursor.sh resolve them the same way as macOS.
let
  themes = [
    "Moga"
    "Hatsune-Miku"
    "Mita"
    "Overwatch-Pointer"
    "Gradient-Blue"
    "Terracota"
  ];

  link = name: {
    name = name;
    value = {
      source = "${pkgs.aurora-cursors}/share/icons/${name}";
      force = true;
    };
  };
in
{
  home.packages = [ pkgs.aurora-cursors ];

  xdg.dataFile = lib.listToAttrs (
    map (name: {
      name = "icons/${name}";
      value = (link name).value;
    }) themes
  );

  home.file = lib.listToAttrs (
    map (name: {
      name = ".icons/${name}";
      value = (link name).value;
    }) themes
  );
}
