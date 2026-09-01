{
  description = "My NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      params = import ./configurations-params/home-pc.nix;
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = params.systemArch;

        specialArgs = {
          inherit params;
        };

        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./users.nix
          ./nvidia.nix
          ./hyprland.nix
        ];
      };
    };
}
