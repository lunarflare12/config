{
  lib,
  params,
  host,
  ...
}:

{
  users.users = lib.mapAttrs (_name: user: {
    isNormalUser = true;
    inherit (user) description;
    extraGroups = lib.unique (
      user.extraGroups
      ++ [
        "input"
        "i2c"
        "gamemode"
      ]
      ++ lib.optionals (host.enabled "docker") [ "docker" ]
      ++ lib.optionals (host.enabled "steam") [ "steam" ]
      ++ lib.optionals (host.enabled "libvirt" || host.enabled "virt-manager") [
        "libvirtd"
        "kvm"
      ]
    );
  }) params.users;
}
