{ lib, root, flakeSelf }:

let
  hardwareProfiles = import (root + "/hardware");
  sharedConfig = import (root + "/config/shared.nix");
  kernels = import (root + "/config/kernels.nix");
  drivers = import (root + "/config/drivers.nix");
  sanitizeLabel = import ./sanitize-label.nix lib;

  gitRevision =
    if flakeSelf ? rev then flakeSelf.shortRev
    else if flakeSelf ? dirtyRev then "${builtins.substring 0 7 flakeSelf.dirtyRev}-dirty"
    else "no-git";

  buildSystemLabel = hostName: hostDefinition:
    sanitizeLabel (lib.concatStringsSep "_" (lib.filter (part: part != "") [
      hostName
      hostDefinition.hostname
      gitRevision
      hostDefinition.buildLabel or ""
    ]));

in hostName: hostDefinitionFile: let
  hostDefinition = import hostDefinitionFile {
    inherit hardwareProfiles sharedConfig kernels drivers;
  };
  hardwareProfile = import hostDefinition.hardwareProfile;
in lib.nixosSystem {
  system = hardwareProfile.system;
  modules = [
    hardwareProfile.module
    (root + "/modules/common.nix")
    {
      networking.hostName = hostDefinition.hostname;
      time.timeZone = hostDefinition.timezone;
      system.stateVersion = hostDefinition.stateVersion;
      system.nixos.label = lib.substring 0 80 (buildSystemLabel hostName hostDefinition);
    }
    (import ./apply-kernel.nix hostDefinition.kernel)
    (import ./apply-nvidia.nix hostDefinition.nvidiaDriver)
    (import ./apply-accounts.nix hostDefinition.accounts)
  ];
}
