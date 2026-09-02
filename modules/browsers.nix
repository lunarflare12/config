{
  lib,
  pkgs,
  params,
  ...
}:

let
  browsers = params.browsers or [ params.browser ];
in
lib.mkMerge (
  (map (
    name:
    if name == "firefox" then
      { programs.firefox.enable = true; }
    else
      { environment.systemPackages = [ pkgs.${name} ]; }
  ) browsers)
  ++ [
    {
      environment.sessionVariables.BROWSER = params.browser;
    }
  ]
)
