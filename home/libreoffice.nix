{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.activation.libreofficeOfficeUi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${config.home.homeDirectory}/.config/libreoffice/4/.lock" ]; then
      ${pkgs.python3}/bin/python3 ${./dots/scripts/libreoffice-office-ui.py} || true
    fi
  '';
}
