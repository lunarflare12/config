{ pkgs, lib, ... }:
let
  steamDir = "/games/Steam";
  steamBin = "${pkgs.steam}/bin/steam";
in {
  home.activation.steamOnGames = lib.hm.dag.entryAfter ["writeBoundary"] ''
    target="$HOME/.local/share/Steam"
    gamesDir="${steamDir}"

    $DRY_RUN_CMD mkdir -p /games "$(dirname "$target")"

    if [ -L "$target" ]; then
      :
    elif [ -d "$target" ]; then
      $DRY_RUN_CMD rm -rf "$gamesDir"
      $DRY_RUN_CMD mv "$target" "$gamesDir"
      $DRY_RUN_CMD ln -sfn "$gamesDir" "$target"
    else
      $DRY_RUN_CMD mkdir -p "$gamesDir"
      $DRY_RUN_CMD ln -sfn "$gamesDir" "$target"
    fi
  '';

  home.packages = [
    (pkgs.writeShellScriptBin "steam" ''
      gamesDir="${steamDir}"
      vdf="$HOME/.local/share/Steam/config/libraryfolders.vdf"

      if [ -f "$vdf" ] && grep -q "$HOME/.local/share/Steam" "$vdf"; then
        sed -i "s|$HOME/.local/share/Steam|$gamesDir|g" "$vdf"
      fi

      exec ${steamBin} "$@"
    '')
  ];
}
