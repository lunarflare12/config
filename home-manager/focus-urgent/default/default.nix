{ pkgs, ... }:
let
  focusUrgent = pkgs.writeShellApplication {
    name = "niri-focus-urgent";
    runtimeInputs = [ pkgs.jq pkgs.niri pkgs.libnotify ];
    text = ''
      id=$(niri msg --json windows \
            | jq -r 'map(select(.is_urgent == true)) | first | .id // empty')
      if [[ -z "$id" ]]; then
        notify-send -t 1500 "niri" "No urgent windows" 2>/dev/null || true
        exit 0
      fi
      niri msg action focus-window --id "$id"
    '';
  };
in
{
  home.packages = [ focusUrgent ];
}
