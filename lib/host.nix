{ lib, root, flakeSelf, home-manager }:

let
  sanitizeLabel = import ./sanitize-label.nix lib;

  gitRevision =
    if flakeSelf ? rev then flakeSelf.shortRev
    else if flakeSelf ? dirtyRev then "${builtins.substring 0 7 flakeSelf.dirtyRev}-dirty"
    else "no-git";

  buildSystemLabel = hostName: host:
    sanitizeLabel (lib.concatStringsSep "_" (lib.filter (part: part != "") [
      hostName
      host.hostname
      gitRevision
      host.buildLabel or ""
    ]));

in hostName: hostFile: let
  hardware = import (root + "/hardware");
  shared = import (root + "/shared");
  host = import hostFile { inherit hardware shared; };
  hardwareProfile = import host.hardwareProfile;
in lib.nixosSystem {
  system = hardwareProfile.system;
  modules = [
    hardwareProfile.module
    (root + "/modules/common.nix")
    {
      networking.hostName = host.hostname;
      time.timeZone = host.timezone;
      system.stateVersion = host.stateVersion;
      system.nixos.label = lib.substring 0 80 (buildSystemLabel hostName host);
    }
    (import (root + "/modules/kernel.nix") host.kernel)
    (import (root + "/modules/nvidia.nix") {
      driver = host.nvidiaDriver;
      graphics = host.graphics;
    })
    (import (root + "/modules/accounts.nix") host.accounts)
    (import (root + "/modules/home.nix") {
      inherit home-manager root;
      accounts = host.accounts;
      stateVersion = host.stateVersion;
    })
  ];
}
