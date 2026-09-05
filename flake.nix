{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      params = import ./configurations-params/home-pc.nix (import ./configurations-params/global.nix);
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = params.systemArch;
        specialArgs = {
          inherit params;
          inherit inputs;
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
