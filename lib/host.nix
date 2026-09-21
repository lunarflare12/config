{ lib, params }:

{
  inherit params;

  userName = params.userName or (lib.head (lib.attrNames params.users));

  repoRel = params.repo or "projects/config";

  repoPath = home: "${home}/${params.repo or "projects/config"}";

  enabled = name: params.features.${name} or false;

  resolve =
    pkgs: name:
    let
      pkg = lib.attrByPath (lib.splitString "." name) null pkgs;
    in
    if pkg != null then pkg else throw "Unknown host package '${name}'";
}
