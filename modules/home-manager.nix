{
  lib,
  params,
  inputs,
  host,
  desktopEnv,
  space,
  ...
}:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm.bak";
    overwriteBackup = true;
    extraSpecialArgs = {
      inherit
        params
        inputs
        host
        desktopEnv
        space
        ;
    };
    users = lib.mapAttrs (_: _: import ../home) params.users;
  };
}
