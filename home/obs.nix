{ lib, pkgs, ... }:

{
  xdg.configFile."environment.d/90-nvenc.conf" = {
    force = true;
    text = ''
      LD_LIBRARY_PATH=/run/opengl-driver/lib
    '';
  };

  # Steam launch options still point here on this machine.
  home.file.".local/bin/overwatch-stream" = {
    source = ./dots/scripts/overwatch-stream.sh;
    force = true;
    executable = true;
  };
  home.file.".local/bin/overwatch-stream.sh" = {
    source = ./dots/scripts/overwatch-stream.sh;
    force = true;
    executable = true;
  };

  home.activation.seedObsStudio = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.config/obs-studio"
    src="${./dots/obs-studio}"
    mkdir -p "$dest" "$HOME/Videos"
    ${pkgs.rsync}/bin/rsync -r --chmod=Du=rwx,Fu+rw --ignore-existing "$src/" "$dest/"

    # Stale nix-profile wrapper; system OBS + environment.d handle NVENC.
    rm -f "$HOME/.local/bin/obs"
  '';
}
