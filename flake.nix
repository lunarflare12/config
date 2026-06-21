{
  description = "NixOS configuration";

  # keep in sync with shared/repos.nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      nixos = import ./system-configuration {
        inherit nixpkgs home-manager;
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
