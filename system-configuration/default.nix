{ nixpkgs, nixpkgs-unstable, home-manager, zen-browser-flake, flakeSelf, root }:
let
  lib = nixpkgs.lib;
  paths = import ./paths.nix root;
  buildHost = import ./host.nix {
    inherit lib nixpkgs-unstable home-manager zen-browser-flake paths flakeSelf;
  };

  profiles = lib.filterAttrs (_: type: type == "directory") (
    builtins.readDir paths.profileDir
  );

  hostsOfProfile = profile:
    let
      profilePath = "${paths.profileDir}/${profile}";
    in
    lib.mapAttrs' (file: _: {
      name = lib.removeSuffix ".nix" file;
      value = buildHost (lib.removeSuffix ".nix" file) "${profilePath}/${file}";
    }) (lib.filterAttrs (_: type: type == "regular") (builtins.readDir profilePath));

in {
  nixosConfigurations = lib.foldl' lib.recursiveUpdate { } (
    map hostsOfProfile (lib.attrNames profiles)
  );
}
