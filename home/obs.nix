{ lib, pkgs, ... }:

{
  xdg.configFile."environment.d/90-nvenc.conf" = {
    force = true;
    text = ''
      LD_LIBRARY_PATH=/run/opengl-driver/lib
    '';
  };

  # Absolute Exec — bare `obs` looked like a broken shortcut when a launcher
  # inherited a thin PATH, and ~/.local/bin/obs stubs were wiped on activate.
  xdg.desktopEntries."com.obsproject.Studio" = {
    name = "OBS Studio";
    genericName = "Streaming/Recording Software";
    comment = "Free and Open Source Streaming/Recording Software";
    # System obs-studio (with plugins) lives on the current-system profile, not
    # bare pkgs.obs-studio — that would drop vkcapture/pipewire plugins.
    # Absolute wrapper — thin Hypr PATH + skip VAAPI probe stalls (see obs.sh).
    exec = "/home/dd/.config/scripts/obs.sh %U";
    icon = "com.obsproject.Studio";
    terminal = false;
    categories = [
      "AudioVideo"
      "Recorder"
    ];
    startupNotify = true;
    # Actual Wayland app_id is com.obsproject.studio, not bare "obs".
    settings.StartupWMClass = "com.obsproject.studio";
  };

  home.activation.seedObsStudio = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.config/obs-studio"
    src="${./dots/obs-studio}"
    mkdir -p "$dest" "$HOME/Videos"
    ${pkgs.rsync}/bin/rsync -r --chmod=Du=rwx,Fu+rw --ignore-existing "$src/" "$dest/"

    # Stale nix-profile wrapper + hand-copied desktop that shadows HM.
    rm -f "$HOME/.local/bin/obs"
    rm -f "$HOME/.local/share/applications/com.obsproject.Studio.desktop"

    # Close-to-tray keeps the warm instance alive after the user hides OBS.
    if [ -f "$dest/global.ini" ]; then
      ${pkgs.gnused}/bin/sed -i \
        -e 's/^SysTrayEnabled=.*/SysTrayEnabled=true/' \
        -e 's/^SysTrayWhenStarted=.*/SysTrayWhenStarted=true/' \
        "$dest/global.ini" || true
      ${pkgs.gnused}/bin/grep -q '^SysTrayEnabled=' "$dest/global.ini" \
        || printf '\nSysTrayEnabled=true\n' >> "$dest/global.ini"
      ${pkgs.gnused}/bin/grep -q '^SysTrayWhenStarted=' "$dest/global.ini" \
        || printf 'SysTrayWhenStarted=true\n' >> "$dest/global.ini"
    fi
  '';
}
