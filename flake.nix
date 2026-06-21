{
  description = "NixOS configuration";

  inputs = let
    repos = import ./shared/repos.nix;
  in {
    nixpkgs.url = repos.nixpkgs;
    home-manager = {
      url = repos.home-manager;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
    import ./lib {
      inherit nixpkgs home-manager;
      flakeSelf = self;
      root = ./.;
    };
}
