{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
  wrap =
    name: command:
    pkgs.writeShellApplication {
      inherit name;
      text = command;
    };
  # Shadow the module-installed `spotify` so PATH/desktop always enter the box.
  boxedSpotify = lib.hiPrio (
    wrap "spotify" ''
      export SPOTIFY_BIN=${lib.escapeShellArg (lib.getExe config.programs.spicetify.spicedSpotify)}
      export SPICETIFY_BIN=${lib.escapeShellArg (lib.getExe config.programs.spicetify.spicetifyPackage)}
      exec ${./dots/scripts/spotify.sh} "$@"
    ''
  );
  boxedSpicetify = wrap "spicetify" ''
    export SPOTIFY_BIN=${lib.escapeShellArg (lib.getExe config.programs.spicetify.spicedSpotify)}
    export SPICETIFY_BIN=${lib.escapeShellArg (lib.getExe config.programs.spicetify.spicetifyPackage)}
    exec ${./dots/scripts/spotify.sh} --cli "$@"
  '';
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  programs.spicetify = {
    enable = true;
    wayland = true;
    # Official collection: https://github.com/spicetify/spicetify-themes
    # Lunar is the closest Dribbblish scheme to macOS Golden Gate.
    theme = spicePkgs.themes.dribbblish;
    colorScheme = "lunar";
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      hidePodcasts
      shuffle
      # https://github.com/rxri/spicetify-extensions
      songStats
      featureShuffle
      wikify
      writeify
      phraseToPlaylist
    ];
    enabledCustomApps = with spicePkgs.apps; [
      marketplace
    ];
  };

  home.packages = [
    boxedSpotify
    boxedSpicetify
  ];

  xdg.desktopEntries.spotify = {
    name = "Spotify";
    genericName = "Music Player";
    exec = "${config.home.homeDirectory}/.config/scripts/spotify";
    icon = "spotify-client";
    categories = [
      "Audio"
      "Music"
      "Player"
      "AudioVideo"
    ];
    mimeType = [ "x-scheme-handler/spotify" ];
    terminal = false;
    startupNotify = true;
    settings.StartupWMClass = "spotify";
  };

  # User data dir beats ~/.nix-profile, which was shadowing the boxed build.
  xdg.dataFile."applications/spotify.desktop" = {
    force = true;
    text = ''
      [Desktop Entry]
      Type=Application
      Name=Spotify
      GenericName=Music Player
      Icon=spotify-client
      Exec=${config.home.homeDirectory}/.config/scripts/spotify
      Terminal=false
      MimeType=x-scheme-handler/spotify;
      Categories=Audio;Music;Player;AudioVideo;
      StartupNotify=true
      StartupWMClass=spotify
    '';
  };
}
