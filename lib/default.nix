{ nixpkgs, home-manager, flakeSelf, root }:

let
  lib = nixpkgs.lib;
  buildHost = import ./host.nix { inherit lib home-manager root flakeSelf; };
in {
  nixosConfigurations = lib.mapAttrs'
    (file: _: {
      name = lib.removeSuffix ".nix" file;
      value = buildHost (lib.removeSuffix ".nix" file) (root + "/hosts/${file}");
    })
    (lib.filterAttrs
      (_: type: type == "regular")
      (builtins.readDir (root + "/hosts")));
}
