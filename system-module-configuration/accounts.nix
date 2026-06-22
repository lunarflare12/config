accountList: { pkgs, lib, ... }:
let
  usesZsh = lib.any (account: account.shell == "zsh") accountList;
in {
  programs.zsh.enable = lib.mkIf usesZsh true;

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
