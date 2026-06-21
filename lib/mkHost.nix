{ lib, root, self }:

let
  hardware = import (root + "/hardware");
  params = import (root + "/config/default.nix");

  rev =
    if self ? rev then self.shortRev
    else if self ? dirtyRev then "${builtins.substring 0 7 self.dirtyRev}-dirty"
    else "no-git";

  sanitizeLabel = s:
    lib.concatStrings (map (c:
      if builtins.match "[a-zA-Z0-9:_.-]" c != null then c else "_"
    ) (lib.stringToCharacters s));

  mkLabel = hostName: host:
    sanitizeLabel (lib.concatStringsSep "_" (lib.filter (s: s != "") [
      hostName
      host.hostName
      rev
      host.snapshot or ""
    ]));

in hostName: hostFile: let
  host = import hostFile { config = hardware; inherit params; };
  hw = import host.hardware;
in lib.nixosSystem {
  system = hw.systemType;
  modules = [
    hw.module
    (root + "/common.nix")
    {
      networking.hostName = host.hostName;
      time.timeZone = host.timeZone;
      system.stateVersion = host.stateVersion;
      system.nixos.label = lib.substring 0 80 (mkLabel hostName host);
    }
    (import ./usersModule.nix host.users)
  ];
}
