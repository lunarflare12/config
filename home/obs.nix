{ lib, pkgs, ... }:

{
  xdg.configFile."environment.d/90-nvenc.conf" = {
    force = true;
    text = ''
      LD_LIBRARY_PATH=/run/opengl-driver/lib
    '';
  };

  # Local copy used to point at ~/.local/bin/obs, which activation deletes.
  xdg.desktopEntries."com.obsproject.Studio" = {
    name = "OBS Studio";
    genericName = "Streaming/Recording Software";
    comment = "Free and Open Source Streaming/Recording Software";
    exec = "env LD_LIBRARY_PATH=/run/opengl-driver/lib obs";
    icon = "com.obsproject.Studio";
    terminal = false;
    categories = [
      "AudioVideo"
      "Recorder"
    ];
    startupNotify = true;
    settings.StartupWMClass = "obs";
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
