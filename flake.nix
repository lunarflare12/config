{
  description = "NixOS configuration";

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
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      params = import ./configurations-params/home-pc.nix (import ./configurations-params/global.nix);
      inherit (params) systemArch;
      pkgs = nixpkgs.legacyPackages.${systemArch};
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        system = systemArch;
        specialArgs = {
          inherit params inputs;
        };
        modules = [
          ./configuration.nix
          ./hardware-configuration.nix
          ./modules
          home-manager.nixosModules.home-manager
        ];
      };

      formatter.${systemArch} = pkgs.nixfmt-tree;

      devShells.${systemArch}.default = pkgs.mkShellNoCC {
        packages = [
          pkgs.nixfmt
          pkgs.statix
          pkgs.deadnix
        ];
      };

      checks.${systemArch}.eval = pkgs.writeText "nixos-eval" (
        self.nixosConfigurations.nixos.config.system.stateVersion
      );
    };
}
