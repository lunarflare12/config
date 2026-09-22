{
  lib,
  python3,
  gtk3,
  wrapGAppsHook3,
  gobject-introspection,
  makeWrapper,
  stdenv,
  script,
}:

let
  pythonEnv = python3.withPackages (ps: [ ps.pygobject3 ]);
in
stdenv.mkDerivation {
  pname = "finder-pick";
  version = "1.0";
  src = script;
  dontUnpack = true;
  nativeBuildInputs = [
    wrapGAppsHook3
    gobject-introspection
    makeWrapper
  ];
  buildInputs = [
    gtk3
    pythonEnv
  ];
  dontWrapGApps = true;
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share $out/bin
    cp $src $out/share/finder-pick.py
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/finder-pick \
      --add-flags "$out/share/finder-pick.py" \
      --set GTK_THEME WhiteSur-Dark \
      --set GTK_APPLICATION_PREFER_DARK_THEME 1 \
      --set GTK_USE_PORTAL 0 \
      --set GDK_DEBUG no-portals \
      --set ADW_DEBUG_COLOR_SCHEME prefer-dark
    runHook postInstall
  '';
  preFixup = ''
    wrapProgram "$out/bin/finder-pick" "''${gappsWrapperArgs[@]}"
  '';
  meta = {
    description = "WhiteSur / Finder-backed portal file picker";
    platforms = lib.platforms.linux;
  };
}
