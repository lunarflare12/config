{
  description = "NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: let
    lib = nixpkgs.lib;
    hardware = import ./hardware;

    mkHost = hostFile: let
      host = import hostFile { config = hardware; };
      hw = import host.hardware;
    in lib.nixosSystem {
      system = hw.systemType;
      modules = [
        hw.module
        ./common.nix
        {
          networking.hostName = host.hostName;
          time.timeZone = host.timeZone;
          system.stateVersion = host.stateVersion;
        }
        (host.module or (_: { }))
      ];
    };

    hostFiles = lib.filterAttrs
      (name: type: type == "regular" && lib.hasSuffix ".nix" name)
      (builtins.readDir ./config);
  in {
    nixosConfigurations = lib.mapAttrs'
      (file: _: {
        name = lib.removeSuffix ".nix" file;
        value = mkHost (./config + "/${file}");
      })
      hostFiles;
  };
}
