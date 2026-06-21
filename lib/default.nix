{ nixpkgs, root }:

let
  lib = nixpkgs.lib;
  mkHost = import ./mkHost.nix { inherit lib root; };

  hostFiles = lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
    (builtins.readDir (root + "/config"));
in {
  nixosConfigurations = lib.mapAttrs'
    (file: _: {
      name = lib.removeSuffix ".nix" file;
      value = mkHost (root + "/config/${file}");
    })
    hostFiles;
}
