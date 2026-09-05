{ lib, pkgs, ... }:

{
  home.activation.seedObsStudio = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.config/obs-studio"
    src="${./dots/obs-studio}"
    mkdir -p "$dest" "$HOME/Videos"
    ${pkgs.rsync}/bin/rsync -r --chmod=Du=rwx,Fu+rw --ignore-existing "$src/" "$dest/"
  '';
}
