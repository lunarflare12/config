{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.activation.libreofficeOfficeUi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    loHome="${config.home.homeDirectory}/programs/libreoffice"
    if [ ! -e "$loHome/.config/libreoffice/4/.lock" ]; then
      HOME="$loHome" ${pkgs.python3}/bin/python3 ${./dots/scripts/libreoffice-office-ui.py} || true
    fi
  '';
}
