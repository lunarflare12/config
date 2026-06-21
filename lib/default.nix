{ nixpkgs, flakeSelf, root }:

let
  lib = nixpkgs.lib;
  buildHost = import ./build-host.nix { inherit lib root flakeSelf; };

  hostDefinitionFiles = lib.filterAttrs
    (fileName: fileType:
      fileType == "regular"
      && lib.hasSuffix ".nix" fileName
      && fileName != "shared.nix"
      && fileName != "kernels.nix"
      && fileName != "drivers.nix")
    (builtins.readDir (root + "/config"));
in {
  nixosConfigurations = lib.mapAttrs'
    (fileName: _: {
      name = lib.removeSuffix ".nix" fileName;
      value = buildHost (lib.removeSuffix ".nix" fileName) (root + "/config/${fileName}");
    })
    hostDefinitionFiles;
}
