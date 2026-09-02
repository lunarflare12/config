{ lib, pkgs, params, ... }:

let
  fileManagers = {
    thunar = pkgs.thunar;
  };
in
{
  programs.firefox.enable = params.browser == "firefox";

  home.packages = [
    (fileManagers.${params.fileManager} or pkgs.${params.fileManager})
  ]
  ++ lib.optional (params.browser != "firefox") pkgs.${params.browser};
}
