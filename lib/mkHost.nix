{ lib, root }:

let
  hardware = import (root + "/hardware");
  params = import (root + "/config/default.nix");

in hostFile: let
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
    }
    (import ./usersModule.nix host.users)
  ];
}
