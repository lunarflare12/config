usersList: { pkgs, lib, ... }: {
  programs.zsh.enable = lib.any (u: u.shell == "zsh") usersList;

  users.users = lib.listToAttrs (map (u: {
    name = u.name;
    value = {
      isNormalUser = true;
      shell = pkgs.${u.shell};
      extraGroups = u.groups;
      packages = map (p: pkgs.${p}) u.packages;
    };
  }) usersList);
}
