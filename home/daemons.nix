{
  config,
  lib,
  params,
  ...
}:

# Personal user daemons — unit files live in home/dots/daemons/.
# Drop a *.service there; it is linked into ~/.config/systemd/user/ and
# enabled on activate. Manage with: systemctl --user start|stop|status <name>
let
  repoRoot = "${config.home.homeDirectory}/${params.repo}";
  daemonsSrc = "${repoRoot}/home/dots/daemons";
  entries = builtins.readDir ./dots/daemons;
  serviceNames = lib.attrNames (
    lib.filterAttrs (name: type: type == "regular" && lib.hasSuffix ".service" name) entries
  );
in
{
  xdg.configFile."daemons" = {
    source = config.lib.file.mkOutOfStoreSymlink daemonsSrc;
    force = true;
  };

  xdg.configFile = lib.listToAttrs (
    map (name: {
      name = "systemd/user/${name}";
      value = {
        source = config.lib.file.mkOutOfStoreSymlink "${daemonsSrc}/${name}";
        force = true;
      };
    }) serviceNames
  );

  home.activation.enablePersonalDaemons = lib.hm.dag.entryAfter [ "reloadSystemd" ] (
    lib.concatMapStrings (name: ''
      $DRY_RUN_CMD systemctl --user enable --quiet ${lib.escapeShellArg name} || true
    '') serviceNames
  );
}
