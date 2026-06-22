{ accounts, homeManagerModules, stateVersion }:
{ lib, ... }: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users = lib.genAttrs (map (account: account.name) accounts) (
    name: {
      home.stateVersion = stateVersion;
      imports = homeManagerModules;
    }
  );
}
