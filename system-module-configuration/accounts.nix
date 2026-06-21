accountList: { pkgs, lib, ... }: {
  users.users = lib.listToAttrs (
    map
      (account: {
        name = account.name;
        value = {
          isNormalUser = true;
          shell = pkgs.${account.shell};
          extraGroups = account.groups;
          packages = map (packageName: pkgs.${packageName}) account.packages;
        };
      })
      accountList
  );
}
