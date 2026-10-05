final: prev: {
  insta360-link-controller = final.callPackage ./insta360-link-controller.nix { };
  excalifont = final.callPackage ./excalifont.nix { };
  openlens = final.callPackage ./openlens.nix { };
  aurora-helpers = final.callPackage ./aurora-helpers.nix { };
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
    hypr-window-shade = prev.callPackage ./hypr-window-shade.nix {
      inherit (prev.hyprlandPlugins) mkHyprlandPlugin;
    };
    # Stock vkfix damages the whole monitor every OW frame (200 Hz × two
    # outputs). That hitch is not the 16:9 stretch. Damage only the window.
    csgo-vulkan-fix = prev.hyprlandPlugins.csgo-vulkan-fix.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        substituteInPlace main.cpp \
          --replace-fail 'g_pHyprRenderer->damageMonitor(PMONITOR);' \
          'g_pHyprRenderer->damageWindow(WINDOW);'
      '';
    });
  };
}
