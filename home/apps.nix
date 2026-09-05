{ lib, pkgs, params, inputs, ... }:

let
  fileManagers = {
    thunar = pkgs.thunar;
  };

  zenBrowser =
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  programs.firefox.enable = params.browser == "firefox";

  home.packages = [
    (fileManagers.${params.fileManager} or pkgs.${params.fileManager})
    zenBrowser
    pkgs.xrandr
  ]
  ++ lib.optional (params.browser != "firefox") pkgs.${params.browser};
}
