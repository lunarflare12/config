{ config, lib, pkgs, ... }:
let
  setDefaultSink = pkgs.writeShellApplication {
    name = "set-default-audio-sink";
    runtimeInputs = [ pkgs.wireplumber ];
    text = ''
      set -euo pipefail

      sink=$(
        wpctl status 2>/dev/null \
          | grep -i hdmi \
          | head -1 \
          | sed -E 's/[^0-9]*([0-9]+).*/\1/'
      )

      if [[ -n "''${sink:-}" ]]; then
        wpctl set-default "$sink"
      fi
    '';
  };
in {
  xdg.configFile."wireplumber/wireplumber.conf.d/51-hdmi-priority.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [
          {
            device.name = "~alsa_card.pci-.*"
            node.name = "~alsa_output.*hdmi.*"
          }
        ]
        actions = {
          update-props = {
            priority.session = 2000
            priority.driver = 2000
          }
        }
      }
      {
        matches = [
          {
            device.name = "~alsa_card.usb-.*"
            node.name = "~alsa_output.*"
          }
        ]
        actions = {
          update-props = {
            priority.session = 100
            priority.driver = 100
          }
        }
      }
    ]
  '';

  home.packages = [ setDefaultSink ];

  home.activation.setDefaultAudioSink = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${setDefaultSink}/bin/set-default-audio-sink || true
  '';
}
