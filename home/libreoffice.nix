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
      HOME="$loHome" ${pkgs.python3}/bin/python3 ${./dots/scripts/libreoffice-office-ui.py} || true
    fi
  '';
}
