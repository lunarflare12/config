hl.layer_rule({
    name = "wallpaper",
    match = { namespace = "^(awww-daemon|awww|swww-daemon|wallpaper)$" },
    blur = false,
    order = 0,
})

hl.layer_rule({
    name = "mpvpaper",
    match = { namespace = "^mpvpaper$" },
    blur = false,
    order = 1,
})

-- Compositor kawase blur on a layer is drawn by Hyprland, not Quickshell.
-- On NVIDIA a tall/wide blurred layer (the old 2560x666 bar host) glitches
-- and kills other windows. The bar paints its own frost in QML (Glass.qml).
hl.layer_rule({
    name = "aurora-desktop",
    match = { namespace = "^aurora-desktop$" },
    blur = false,
    order = 2,
})

hl.layer_rule({
    name = "aurora-desktop-metrics",
    match = { namespace = "^aurora-desktop-metrics$" },
    blur = false,
    order = 4,
})

hl.layer_rule({
    name = "aurora-dim",
    match = { namespace = "^aurora-dim$" },
    blur = false,
    xray = true,
    order = 8,
})

hl.layer_rule({
    name = "aurora-bar",
    match = { namespace = "^aurora-bar$" },
    blur = false,
    order = 10,
})

hl.layer_rule({
    name = "aurora-dock",
    match = { namespace = "^aurora-dock$" },
    blur = false,
    order = 13,
})

hl.layer_rule({
    name = "aurora-launcher",
    match = { namespace = "^aurora-launcher$" },
    blur = false,
    order = 12,
})

hl.layer_rule({
    name = "aurora-overview",
    match = { namespace = "^aurora-overview$" },
    blur = false,
    order = 14,
})

hl.layer_rule({
    name = "aurora-popup",
    match = { namespace = "^aurora-popup$" },
    blur = false,
    -- The card slides out of the bar in QML. A compositor fade on the
    -- whole layer hides that motion.
    no_anim = true,
    order = 6,
})

hl.layer_rule({
    name = "aurora-frame",
    match = { namespace = "^aurora-frame-" },
    blur = false,
    no_anim = true,
    order = 15,
})

hl.layer_rule({
    name = "aurora-notifications",
    match = { namespace = "^aurora-notifications$" },
    blur = false,
    order = 8,
})

hl.layer_rule({
    name = "aurora-screenshot",
    match = { namespace = "^aurora-screenshot$" },
    blur = false,
    no_anim = true,
    order = 16,
})

hl.layer_rule({
    name = "aurora-preview",
    match = { namespace = "^aurora-preview$" },
    blur = false,
    order = 17,
})

hl.layer_rule({
    name = "aurora-shaders",
    match = { namespace = "^aurora-shaders$" },
    blur = false,
    order = 18,
})

hl.layer_rule({
    name = "screen-capture",
    match = { namespace = "^(selection|slurp|grim|hyprpicker|satty)$" },
    blur = false,
    xray = true,
    order = 15,
})
