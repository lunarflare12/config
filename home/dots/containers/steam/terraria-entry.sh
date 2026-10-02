#!/bin/sh
# Terraria box: silent Steam + game, then exit when Terraria exits.
exec /usr/local/bin/game-session.sh 105600 \
  'Terraria.bin' \
  'Terraria.exe'
