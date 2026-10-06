{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  alsa-lib,
  at-spi2-atk,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  glib,
  gtk3,
  libdrm,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  udev,
  xorg,
}:

stdenv.mkDerivation rec {
  pname = "balena-etcher";
  version = "2.1.4";

  src = fetchurl {
    url = "https://github.com/balena-io/etcher/releases/download/v${version}/balenaEtcher-linux-x64-${version}.zip";
    hash = "sha256-sOCPABzBXLDWSIMtsdIyc6pv8lERvBBLi8H3lKqWFtk=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    atk
    cairo
    cups
    dbus
    expat
    glib
    gtk3
    libdrm
    libxkbcommon
    mesa
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    udev
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
  ];

  sourceRoot = "balenaEtcher-linux-x64";
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/balena-etcher $out/bin
    cp -a . $out/lib/balena-etcher
    # Upstream zip ships a dangling balenaEtcher symlink; the real ELF is balena-etcher.
    rm -f $out/lib/balena-etcher/balenaEtcher
    chmod +x $out/lib/balena-etcher/balena-etcher
    makeWrapper $out/lib/balena-etcher/balena-etcher $out/bin/balena-etcher \
      --chdir $out/lib/balena-etcher \
      --prefix LD_LIBRARY_PATH : ${
        lib.makeLibraryPath [
          udev
          gtk3
        ]
      }
    ln -s $out/bin/balena-etcher $out/bin/etcher
    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "balena-etcher";
      desktopName = "balenaEtcher";
      comment = "Flash OS images to SD cards and USB drives";
      exec = "balena-etcher %F";
      icon = "balena-etcher";
      categories = [
        "Utility"
        "System"
      ];
    })
  ];

  meta = {
    description = "Flash OS images to SD cards and USB drives";
    homepage = "https://etcher.balena.io/";
    license = lib.licenses.asl20;
    mainProgram = "balena-etcher";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
