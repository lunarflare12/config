{ stdenvNoCC }:

stdenvNoCC.mkDerivation {
  pname = "excalifont";
  version = "1.000";
  src = ../modules/fonts/Excalifont-Regular.ttf;
  dontUnpack = true;
  installPhase = ''
    runHook preInstall
    install -Dm644 $src $out/share/fonts/truetype/Excalifont-Regular.ttf
    runHook postInstall
  '';
}
