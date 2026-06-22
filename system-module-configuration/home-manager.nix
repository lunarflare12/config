{ accounts, homeManagerModules, stateVersion, specialArgs ? { } }:
{ lib, ... }: {
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.extraSpecialArgs = specialArgs;

  home-manager.users = lib.genAttrs (map (account: account.name) accounts) (
    name: {
      home.stateVersion = stateVersion;
      imports = homeManagerModules;
    }
  );
}
