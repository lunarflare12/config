{ pkgs, ... }:
let
  restoreWorkspaces = pkgs.writeShellApplication {
    name = "niri-restore-workspaces";
    runtimeInputs = [ pkgs.jq pkgs.niri pkgs.libnotify ];
    text = ''
      set -euo pipefail

      workspace_for_app() {
        case "$1" in
          zen) echo 1 ;;
          kitty) echo 2 ;;
          obsidian) echo 3 ;;
          jetbrains-idea|cursor) echo 4 ;;
          org.telegram.desktop|vesktop|discord|Discord|com.discordapp.Discord|[Ss]team|PrismLauncher|prismlauncher|gamescope|heroic|lutris|osu*|com.mojang.MinecraftLauncher) echo 5 ;;
          *)
            if [[ "$1" =~ \.exe$|[Ww]ine|[Pp]roton ]]; then
              echo 5
            fi
            ;;
        esac
      }

      moved=0
      while IFS= read -r line; do
        id=$(jq -r '.id' <<<"$line")
        app_id=$(jq -r '.app_id // empty' <<<"$line")
        ws_id=$(jq -r '.workspace_id' <<<"$line")
        [[ -z "$app_id" ]] && continue

        target=$(workspace_for_app "$app_id")
        [[ -z "''${target:-}" ]] && continue

        current=$(niri msg --json workspaces | jq -r --argjson wid "$ws_id" \
          '.[] | select(.id == $wid) | .idx')
        [[ "$current" == "$target" ]] && continue

        niri msg action move-window-to-workspace "$target" \
          --window-id "$id" --focus false
        moved=$((moved + 1))
      done < <(niri msg --json windows | jq -c '.[]')

      notify-send -t 1500 "niri" "Restored $moved window(s) to assigned workspaces" \
        2>/dev/null || true
    '';
  };
in
{
  home.packages = [ restoreWorkspaces ];
}
