{
  lib,
  stdenv,
  fetchFromGitHub,
  fpc,
  lazarus-qt5,
  pkg-config,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  libsForQt5,
}:

stdenv.mkDerivation {
  pname = "insta360-link-controller";
  version = "0-unstable-2026-07-12";

  src = fetchFromGitHub {
    owner = "vrwallace";
    repo = "Insta360-Link-1-and-2-Controller-for-Linux";
    rev = "216124b96ec5b6d7f64d4c85d4e3e405f679e1ec";
    hash = "sha256-b5RKy4JLbC/En6eIOFpss0Wnn4zxmiF9k1gvuQhs7y4=";
  };

  patches = [
    ./patches/insta360-skip-uvc-metadata.patch
    ./patches/insta360-gtk3-layout.patch
    ./patches/insta360-gui-bugs.patch
    ./patches/insta360-image-looks.patch
    ./patches/insta360-resolution.patch
    ./patches/insta360-fast-start.patch
  ];

  nativeBuildInputs = [
    fpc
    lazarus-qt5
    pkg-config
    libsForQt5.wrapQtAppsHook
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    libsForQt5.qtbase
    libsForQt5.qtwayland
    libsForQt5.libqtpas
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "insta360linkgui";
      desktopName = "Insta360 Link Controller";
      comment = "PTZ and AI controls for Insta360 Link and Link 2";
      exec = "insta360linkgui";
      icon = "camera-web";
      categories = [
        "AudioVideo"
        "Video"
        "Settings"
      ];
      terminal = false;
    })
  ];

  buildPhase = ''
    runHook preBuild
    export HOME="$TMPDIR"
    lazbuild \
      --lazarusdir=${lazarus-qt5}/share/lazarus \
      --widgetset=qt5 \
      --build-mode=Release \
      --skip-dependencies \
      insta360linkgui.lpi
    fpc -O2 -Fu. linkctl.pas
    runHook postBuild
  '';

  installPhase = ''
        runHook preInstall
        install -Dm755 insta360linkgui $out/bin/insta360linkgui
        install -Dm755 linkctl $out/bin/linkctl
        install -Dm644 /dev/stdin $out/lib/udev/rules.d/99-insta360-link.rules <<'EOF'
    # Insta360 Link / Link 2 — non-root access.
    # uvcvideo re-enables autosuspend on bind, so also RUN after bind.
    SUBSYSTEM=="video4linux", ATTRS{idVendor}=="2e1a", MODE="0666", GROUP="video"
    SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2e1a", MODE="0666"
    ACTION=="add|bind", SUBSYSTEM=="usb", ENV{DEVTYPE}=="usb_device", ATTR{idVendor}=="2e1a", ATTR{power/control}="on", ATTR{power/autosuspend}="-1"
    ACTION=="bind", DRIVER=="uvcvideo", ATTRS{idVendor}=="2e1a", RUN+="/bin/sh -c 'echo on > /sys$env{DEVPATH}/../power/control; echo -1 > /sys$env{DEVPATH}/../power/autosuspend'"
    EOF
        runHook postInstall
  '';

  meta = {
    description = "Linux GUI/CLI controller for Insta360 Link and Link 2 webcams";
    homepage = "https://github.com/vrwallace/Insta360-Link-1-and-2-Controller-for-Linux";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "insta360linkgui";
  };
}
