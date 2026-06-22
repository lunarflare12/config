{
  description = "NixOS configuration";

  # keep in sync with shared/repos.nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser-flake = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, home-manager, zen-browser-flake }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      nixos = import ./system-configuration {
        inherit nixpkgs nixpkgs-unstable home-manager zen-browser-flake;
        flakeSelf = self;
        root = ./.;
      };
    in
    nixos // {
      formatter.${system} = pkgs.alejandra;
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          alejandra
          deadnix
        ];
      };
    };
}
