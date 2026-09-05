{ lib, params, inputs, ... }:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit params inputs;
    };
    users = lib.mapAttrs (_: _: import ../home) params.users;
  };
}
