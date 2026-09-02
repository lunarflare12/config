{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    glyph-sddm = {
      url = "github:xCaptaiN09/glyph-sddm";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      glyph-sddm,
      ...
    }:
    let
      params = import ./configurations-params/home-pc.nix (import ./configurations-params/global.nix);
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = params.systemArch;
        specialArgs = {
          inherit params glyph-sddm;
        };
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./modules
          home-manager.nixosModules.home-manager
        ];
      };
    };
}
