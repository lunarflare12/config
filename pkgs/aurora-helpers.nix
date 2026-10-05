{
  buildGoModule,
  lib,
  makeWrapper,
}:

buildGoModule {
  pname = "aurora-helpers";
  version = "0.3.0";
  src = ../home/dots/go/aurora;
  vendorHash = null;
  env.CGO_ENABLED = "0";
  subPackages = [ "cmd/aurora" ];
  nativeBuildInputs = [ makeWrapper ];
  postInstall = ''
    ln -s aurora $out/bin/aurora-mpris
    ln -s aurora $out/bin/aurora-reaper
    ln -s aurora $out/bin/aurora-wallpaper
    ln -s aurora $out/bin/aurora-hypr-fix
    ln -s aurora $out/bin/aurora-fossilize
    ln -s aurora $out/bin/aurora-monitor
    ln -s aurora $out/bin/aurora-helpers
    ln -s aurora $out/bin/vpn-ctl
    ln -s aurora $out/bin/lab-ctl
    ln -s aurora $out/bin/brightnessctl
    ln -s aurora $out/bin/spotify-theme
    ln -s aurora $out/bin/shader-ctl
    makeWrapper $out/bin/aurora $out/bin/container-xdg-open \
      --add-flags "dispatch" --add-flags "xdg-open"
  '';
}
