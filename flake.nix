{
  description = "NixOS configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { self, nixpkgs, ... }:
    import ./lib {
      inherit nixpkgs;
      flakeSelf = self;
      root = ./.;
    };
}
