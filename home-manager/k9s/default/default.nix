{ pkgs, ... }:
let
  fluxPluginsJson = pkgs.runCommand "k9s-flux-plugins.json" {
    nativeBuildInputs = [ pkgs.yq-go ];
  } ''
    yq -o=json < ${./flux-plugins.yaml} > $out
  '';
  fluxPlugins = (builtins.fromJSON (builtins.readFile fluxPluginsJson)).plugins;
in
{
  programs.k9s = {
    enable = true;

    aliases = {
      git = "source.toolkit.fluxcd.io/v1/gitrepositories";
      gitrepo = "source.toolkit.fluxcd.io/v1/gitrepositories";
      hr = "helm.toolkit.fluxcd.io/v2/helmreleases";
      ks = "kustomize.toolkit.fluxcd.io/v1/kustomizations";
      helmrepo = "source.toolkit.fluxcd.io/v1beta2/helmrepositories";
      oci = "source.toolkit.fluxcd.io/v1beta2/ocirepositories";
    };

    settings = {
      k9s = {
        ui = {
          skin = "catppuccin-mocha";
          noIcons = false;
        };
      };
    };

    skins = {
      catppuccin-mocha = ./catppuccin-mocha.yaml;
    };

    plugins = fluxPlugins;
  };

  home.packages = with pkgs; [
    fluxcd
  ];
}
