{
  lib,
  params,
  inputs,
  host,
  desktopEnv,
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
        ;
    };
    users = lib.mapAttrs (_: _: import ../home) params.users;
  };
}
