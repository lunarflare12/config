{ lib, params, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit params;
    };
    users = lib.mapAttrs (_: _: import ../home) params.users;
  };
}
