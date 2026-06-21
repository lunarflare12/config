{
  description = "NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs = { nixpkgs, ... }: import ./lib { inherit nixpkgs; root = ./.; };
}
