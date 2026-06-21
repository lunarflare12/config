{ lib, root, self }:

let
  hardware = import (root + "/hardware");
  params = import (root + "/config/default.nix");

  rev = self.rev or self.dirtyRev or "no-git";

  mkLabel = hostName: host:
    lib.concatStringsSep " · " (lib.filter (s: s != "") [
      hostName
      host.hostName
      rev
      host.snapshot or ""
    ]);

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
