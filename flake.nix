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
      inherit (nixpkgs) lib;
      params = import ./configurations-params/home-pc.nix;
      inherit (params) systemArch;
      host = import ./lib/host.nix { inherit lib params; };
      desktopEnv = import ./lib/desktop-env.nix;
      overlay = import ./pkgs;
      pkgs = import nixpkgs {
        system = systemArch;
        overlays = [ overlay ];
        config = {
          allowUnfree = true;
          permittedInsecurePackages = [ "idea-oss-2025.3.4" ];
        };
      };
    in
    {
      overlays.default = overlay;

      nixosConfigurations.nixos = lib.nixosSystem {
        specialArgs = {
          inherit
            params
            inputs
            host
            desktopEnv
            ;
        };
        modules = [
          { nixpkgs.pkgs = pkgs; }
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

      checks.${systemArch}.eval = pkgs.runCommand "nixos-eval" {
        inherit (self.nixosConfigurations.nixos.config.system.build.toplevel) drvPath;
      } "echo \"$drvPath\" > \"$out\"";
    };
}
