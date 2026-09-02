{ pkgs, params, ... }:

{
  environment.systemPackages = map (name: pkgs.${name}) (params.terminals or [ params.terminal ]);
  environment.sessionVariables.TERMINAL = params.terminal;
}
