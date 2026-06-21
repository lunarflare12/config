{ accounts, home-manager, homeManagerModules, paths, stateVersion }:
{ lib, ... }: {
  imports = [ home-manager.nixosModules.home-manager ];

  users.users = lib.genAttrs (map (account: account.name) accounts) (
    name: {
      homeManager = {
        home.stateVersion = stateVersion;
        imports = homeManagerModules;
      };
    }
  );
}
