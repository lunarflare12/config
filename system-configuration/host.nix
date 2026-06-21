{ lib, paths, flakeSelf, home-manager }:
let
  shared = import paths.shared;
  hardware = import paths.hardware;
  sanitizeLabel = import "${paths.shared}/sanitize-label.nix" lib;

  gitRevision =
    if flakeSelf ? rev then
      flakeSelf.shortRev
    else if flakeSelf ? dirtyRev then
      "${builtins.substring 0 7 flakeSelf.dirtyRev}-dirty"
    else
      "no-git";

  buildLabel = hostName: host:
    sanitizeLabel (lib.concatStringsSep "_" (lib.filter (part: part != "") [
      hostName
      host.hostname
      gitRevision
      host.buildLabel or ""
    ]));

in
  hostName: hostFile:
    let
      host = import hostFile { inherit hardware shared; };
      hardwareProfile = import host.hardwareProfile;
    in
    lib.nixosSystem {
      system = hardwareProfile.system;
      modules = [
        hardwareProfile.module
        "${paths.modules}/common.nix"
        {
          networking.hostName = host.hostname;
          time.timeZone = host.timezone;
          system.stateVersion = host.stateVersion;
          system.nixos.label = lib.substring 0 80 (buildLabel hostName host);
        }
        (import "${paths.modules}/kernel.nix" host.kernel)
        (import "${paths.modules}/nvidia.nix" {
          driver = host.nvidiaDriver;
          graphics = host.graphics;
        })
        (import "${paths.modules}/accounts.nix" host.accounts)
        (import "${paths.modules}/home-manager.nix" {
          inherit home-manager paths;
          accounts = host.accounts;
          stateVersion = host.stateVersion;
        })
      ];
    }
