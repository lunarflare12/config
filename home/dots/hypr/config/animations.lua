local game_flag = io.open("/home/dd/.local/state/aurora-game", "r")
local in_game = game_flag ~= nil
if game_flag then
    game_flag:close()
end

hl.config({ animations = { enabled = not in_game } })

-- Ease-out that keeps moving through the middle, so the eye gets
-- more in-between frames instead of one jump and a crawl.
hl.curve("smoothOut", { type = "bezier", points = { { 0.22, 0.61 }, { 0.36, 1 } } })

-- Continuous per-frame border work. With 200Hz + 60Hz that is free stutter.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "border", enabled = false })
-- YouTube / HTML5 FS is a windowsMove resize. popin only affects open/close;
-- this lerp is always a growing rectangle, so keep it off.
hl.animation({ leaf = "windowsMove", enabled = false })

for _, animation in ipairs({
    -- GNOME-style grow from the pointer. No parent "windows" style,
    -- or windowsMove would inherit it.
    { leaf = "windowsIn", speed = 2.2, bezier = "smoothOut", style = "gnomed" },
    { leaf = "windowsOut", speed = 1.6, bezier = "smoothOut", style = "gnomed" },
    { leaf = "layers", speed = 2.0, bezier = "smoothOut", style = "fade" },
    { leaf = "layersIn", speed = 1.8, bezier = "smoothOut", style = "fade" },
    { leaf = "fadeIn", speed = 1.6, bezier = "smoothOut" },
    { leaf = "fadeOut", speed = 1.3, bezier = "smoothOut" },
    { leaf = "workspaces", speed = 2.0, bezier = "smoothOut", style = "fade" },
    { leaf = "specialWorkspace", speed = 2.0, bezier = "smoothOut", style = "fade" },
}) do
    animation.enabled = not in_game
    hl.animation(animation)
end
