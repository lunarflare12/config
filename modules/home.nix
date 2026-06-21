{ accounts, home-manager, root, stateVersion }:
{ lib, ... }: {
  imports = [ home-manager.nixosModules.home-manager ];

  users.users = lib.genAttrs (map (account: account.name) accounts) (name: {
    homeManager = import (root + "/home/${name}.nix") { inherit stateVersion; };
  });
}
