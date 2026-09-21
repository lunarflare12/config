final: prev: {
  insta360-link-controller = final.callPackage ./insta360-link-controller.nix { };
  excalifont = final.callPackage ./excalifont.nix { };
  hyprlandPlugins = prev.hyprlandPlugins // {
    csgo-vulkan-fix = prev.hyprlandPlugins.csgo-vulkan-fix.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + ''
        cp ${../home/dots/hypr/plugins/csgo-vulkan-fix/main.cpp} main.cpp
      '';
    });
  };
}
