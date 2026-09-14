{
  lib,
  params,
  ...
}:

let
  hasSteam = lib.elem "steam" (params.packages or [ ]);
in
{
  hardware.nvidia.powerManagement.enable = lib.mkForce false;

  fileSystems."/steam".options = lib.mkIf hasSteam (lib.mkAfter [ "metacopy=on" ]);
}
