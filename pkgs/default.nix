final: prev: {
  insta360-link-controller = final.callPackage ./insta360-link-controller.nix { };
  excalifont = final.callPackage ./excalifont.nix { };
  openlens = final.callPackage ./openlens.nix { };
  finder-pick = final.callPackage ./finder-pick.nix {
    script = ../home/dots/scripts/finder-pick.py;
  };
  aurora-cursors = final.callPackage ./aurora-cursors.nix { };
  thunar-unwrapped = prev.thunar-unwrapped.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/thunar-hide-pathbar-root.patch
      ./patches/thunar-hide-computer-drive.patch
      ./patches/thunar-hide-symlink-emblem.patch
    ];
  });
  hyprlandPlugins = prev.hyprlandPlugins // {
    csgo-vulkan-fix = prev.hyprlandPlugins.csgo-vulkan-fix.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        cp ${../home/dots/hypr/plugins/csgo-vulkan-fix/main.cpp} main.cpp
      '';
    });
  };
}
