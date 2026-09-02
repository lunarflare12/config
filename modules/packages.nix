{ lib, pkgs, params, ... }:

let
  packages = params.packages or [ ];
  has = name: lib.elem name packages;

  packageMap = {
    terraform = pkgs.terraform;
    ansible = pkgs.ansible;
    go = pkgs.go;
    nodejs_latest = pkgs.nodejs_latest;
    python3 = pkgs.python3;
  };
in
{
  virtualisation.docker.enable = has "docker";

  programs.steam = lib.mkIf (has "steam") {
    enable = true;
    extraCompatPackages = [ pkgs.proton-ge-bin ];
    gamescopeSession.enable = true;
  };

  environment.systemPackages = map (name: packageMap.${name}) (
    lib.filter (name: builtins.hasAttr name packageMap) packages
  );

  users.users = lib.mkIf (has "docker") (
    lib.mapAttrs (_: _: {
      extraGroups = [ "docker" ];
    }) params.users
  );
}
