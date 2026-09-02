{
  description = "My NixOS configuration";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { nixpkgs, ... }:
    let
      params = import ./configurations-params/home-pc.nix (import ./configurations-params/global.nix);
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
          ./modules
        ];
      };
    };
}
