{ accounts, home-manager, paths, stateVersion }:
{ lib, ... }: {
  imports = [ home-manager.nixosModules.home-manager ];

  users.users = lib.genAttrs (map (account: account.name) accounts) (
    name: {
      homeManager = import "${paths.homeManager}/${name}.nix" { inherit stateVersion; };
    }
  );
}
