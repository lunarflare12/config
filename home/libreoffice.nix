{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.activation.libreofficeOfficeUi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    loHome="${config.home.homeDirectory}/programs/libreoffice"
    # Always pin dark Colibre + Appearance=Dark when LO is not running.
    # Light colibre was baking light toolbar icons into a dark GTK session.
    if [ ! -e "$loHome/.config/libreoffice/4/.lock" ]; then
      HOME="$loHome" ${pkgs.aurora-helpers}/bin/aurora libreoffice-ui || true
    fi
  '';
}
