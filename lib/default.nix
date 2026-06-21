{ nixpkgs, self, root }:

let
  lib = nixpkgs.lib;
  mkHost = import ./mkHost.nix { inherit lib self root; };

  hostFiles = lib.filterAttrs
    (name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix")
    (builtins.readDir (root + "/config"));
in {
  nixosConfigurations = lib.mapAttrs'
    (file: _: {
      name = lib.removeSuffix ".nix" file;
      value = mkHost (lib.removeSuffix ".nix" file) (root + "/config/${file}");
    })
    hostFiles;
}
