{
  pkgs,
  inputs,
  ...
}:

let
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

  # Build the patched client only. The dock/desktop launcher stays the
  # container shim in apps.nix — do not put a host Spotify on PATH.
  programs.spicetify = {
    enable = false;
    wayland = true;
    theme = spicePkgs.themes.dribbblish;
    colorScheme = "lunar";
    enabledExtensions = with spicePkgs.extensions; [
      adblockify
      hidePodcasts
      shuffle
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
}
