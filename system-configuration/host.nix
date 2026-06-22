{ lib, paths, flakeSelf, home-manager, nixpkgs-unstable, zen-browser-flake }:
let
  shared = import paths.shared;
  hardware = import paths.hardware;
  homeManagerModules = import paths.homeManager;
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
      host = import hostFile { inherit hardware shared homeManagerModules; };
      hardwareProfile = import host.hardwareProfile;
      system = hardwareProfile.system;
      zenBrowser = zen-browser-flake.packages.${system}.zen-browser;
    in
    lib.nixosSystem {
      inherit system;
      modules = [
        {
          nixpkgs.overlays = [
            (_final: _prev: {
              code-cursor =
                (import nixpkgs-unstable {
                  inherit system;
                  config.allowUnfree = true;
                }).code-cursor;
              zen-browser = zenBrowser;
            })
          ];
        }
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
        (import "${paths.modules}/pipewire.nix" (host.audio or { enable = false; }))
        (import "${paths.modules}/accounts.nix" host.accounts)
        (import "${paths.modules}/programs.nix" {
          programs = host.programs or { };
          accounts = host.accounts;
          wm = host.wm or shared.wm.type.none;
          wmTypes = shared.wm.type;
        })
        (import "${paths.modules}/sddm.nix" {
          initSys = host.initSys or shared.initSys.type.none;
          initSysTypes = shared.initSys.type;
          wm = host.wm or shared.wm.type.none;
          wmTypes = shared.wm.type;
          wmConfig = host.wmConfig or { };
          user = (lib.head host.accounts).name;
          hostname = host.hostname;
        })
        home-manager.nixosModules.home-manager
        (import "${paths.modules}/home-manager.nix" {
          accounts = host.accounts;
          stateVersion = host.stateVersion;
          homeManagerModules = host.homeManager;
          specialArgs = {
            wmConfig = host.wmConfig or { };
          };
        })
      ];
    }
