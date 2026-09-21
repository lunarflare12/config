-- Allow screen capture for portals, OBS, and screenshot tools on NixOS.
-- Table form is required on Hyprland 0.56; positional args are ignored.
local function allow_screencopy(binary)
    hl.permission({ binary = binary, type = "screencopy", mode = "allow" })
end

allow_screencopy("/nix/store/.*/libexec/xdg-desktop-portal-hyprland")
allow_screencopy("/nix/store/.*/libexec/.xdg-desktop-portal-hyprland-wrapped")
allow_screencopy("/nix/store/.*/libexec/xdg-desktop-portal-gtk")
allow_screencopy("/nix/store/.*/bin/obs")
allow_screencopy("/nix/store/.*/bin/grim")
allow_screencopy("/nix/store/.*/bin/slurp")
allow_screencopy("/nix/store/.*/bin/satty")
allow_screencopy("/nix/store/.*/bin/hyprpicker")
allow_screencopy("/nix/store/.*/bin/qs")
allow_screencopy("/nix/store/.*/bin/quickshell")

local function allow_plugin(binary)
    hl.permission({ binary = binary, type = "plugin", mode = "allow" })
end

allow_plugin("/nix/store/.*/bin/hyprctl")
allow_plugin("/run/current-system/sw/bin/hyprctl")
allow_plugin("/etc/profiles/per-user/.*/bin/hyprctl")
