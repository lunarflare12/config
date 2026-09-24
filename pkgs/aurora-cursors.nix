{
  lib,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation {
  pname = "aurora-cursors";
  version = "1.0.0";

  src = ../home/dots/cursors/themes;

  dontConfigure = true;
  dontBuild = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/icons"
    for theme in Moga Hatsune-Miku Mita Overwatch-Pointer Gradient-Blue Terracota; do
      cp -a "$theme" "$out/share/icons/"
    done
    runHook postInstall
  '';

  meta = {
    description = "Aurora extra XCursor / hyprcursor packs";
    homepage = "https://vsthemes.org";
    platforms = lib.platforms.linux;
  };
}
