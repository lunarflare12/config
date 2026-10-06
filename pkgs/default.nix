final: prev: {
  insta360-link-controller = final.callPackage ./insta360-link-controller.nix { };
  excalifont = final.callPackage ./excalifont.nix { };
  openlens = final.callPackage ./openlens.nix { };
  aurora-helpers = final.callPackage ./aurora-helpers.nix { };
  finder-pick = final.callPackage ./finder-pick.nix {
    script = ./finder-pick.py;
  };
  aurora-cursors = final.callPackage ./aurora-cursors.nix { };
  balena-etcher = final.callPackage ./balena-etcher.nix { };
  thunar-unwrapped = prev.thunar-unwrapped.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/thunar-hide-pathbar-root.patch
      ./patches/thunar-hide-computer-drive.patch
      ./patches/thunar-hide-symlink-emblem.patch
    ];
  });
  hyprlandPlugins = prev.hyprlandPlugins // {
    hypr-window-shade = prev.callPackage ./hypr-window-shade.nix {
      inherit (prev.hyprlandPlugins) mkHyprlandPlugin;
    };
  };
}
