-- Allow screen capture for portals, OBS, and screenshot tools on NixOS.
hl.permission("/nix/store/.*/libexec/xdg-desktop-portal-hyprland", "screencopy", "allow")
hl.permission("/nix/store/.*/libexec/xdg-desktop-portal-gtk", "screencopy", "allow")
hl.permission("/nix/store/.*/bin/obs", "screencopy", "allow")
hl.permission("/nix/store/.*/bin/grim", "screencopy", "allow")
hl.permission("/nix/store/.*/bin/hyprshot", "screencopy", "allow")
