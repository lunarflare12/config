{ accounts, homeManagerModules, stateVersion }:
{ lib, ... }: {
  users.users = lib.genAttrs (map (account: account.name) accounts) (
    name: {
      homeManager = {
        home.stateVersion = stateVersion;
        imports = homeManagerModules;
      };
    }
  );
}
