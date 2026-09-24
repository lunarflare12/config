{
  lib,
  fetchurl,
  appimageTools,
  makeWrapper,
}:

let
  pname = "openlens";
  version = "6.5.2-366";
  src = fetchurl {
    url = "https://github.com/MuhammedKalkan/OpenLens/releases/download/v${version}/OpenLens-${version}.x86_64.AppImage";
    hash = "sha256-ZAltAS/U/xh4kCT7vQ+NHAzWV7z0uE5GMQICHKSdj8k=";
  };
  appimageContents = appimageTools.extract { inherit pname version src; };
  wrapped = appimageTools.wrapType2 {
    inherit pname version src;

    nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    wrapProgram $out/bin/${pname} \
      --add-flags "--ozone-platform=wayland"
    install -m 444 -D ${appimageContents}/open-lens.desktop $out/share/applications/${pname}.desktop
    substituteInPlace $out/share/applications/${pname}.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=${pname}' \
      --replace-fail 'Icon=open-lens' 'Icon=${pname}'
    install -m 444 -D ${appimageContents}/usr/share/icons/hicolor/512x512/apps/open-lens.png \
      $out/share/icons/hicolor/512x512/apps/${pname}.png
  '';

  meta = {
    description = "Open-source Kubernetes IDE";
    homepage = "https://github.com/MuhammedKalkan/OpenLens";
    license = lib.licenses.mit;
    mainProgram = "openlens";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
};
in
wrapped.overrideAttrs (old: {
  passthru = (old.passthru or { }) // {
    extracted = appimageContents;
  };
})
