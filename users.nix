{
  config,
  pkgs,
  params,
  ...
}:

{
  users.users = builtins.mapAttrs (name: user: {
    isNormalUser = true;
    inherit (user) description extraGroups;
  }) params.users;
}
