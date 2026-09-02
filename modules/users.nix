{ params, ... }:

{
  users.users = builtins.mapAttrs (_: user: {
    isNormalUser = true;
    inherit (user) description extraGroups;
  }) params.users;
}
