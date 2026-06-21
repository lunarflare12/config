accountList: { pkgs, lib, ... }: {
  programs.zsh.enable = lib.any (account: account.shell == "zsh") accountList;

  users.users = lib.listToAttrs (map (account: {
    name = account.name;
    value = {
      isNormalUser = true;
      shell = pkgs.${account.shell};
      extraGroups = account.groups;
      packages = map (packageName: pkgs.${packageName}) account.packages;
    };
  }) accountList);
}
