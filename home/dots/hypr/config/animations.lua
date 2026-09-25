local game_flag = io.open("/home/dd/.local/state/aurora-game", "r")
local in_game = game_flag ~= nil
if game_flag then
    game_flag:close()
end

hl.config({ animations = { enabled = not in_game } })

-- Long ease-out: fast start, soft settle. No overshoot.
hl.curve("smoothOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

-- Continuous per-frame border work. With 200Hz + 60Hz that is free stutter.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "border", enabled = false })
-- YouTube / HTML5 FS is a windowsMove resize. popin only affects open/close;
-- this lerp is always a growing rectangle, so keep it off.
hl.animation({ leaf = "windowsMove", enabled = false })

for _, animation in ipairs({
    -- GNOME-style grow from the pointer. No parent "windows" style,
    -- or windowsMove would inherit it.
    { leaf = "windowsIn", speed = 4.6, bezier = "smoothOut", style = "gnomed" },
    { leaf = "windowsOut", speed = 3.2, bezier = "smoothOut", style = "gnomed" },
    { leaf = "layers", speed = 5, bezier = "smoothOut", style = "fade" },
    { leaf = "layersIn", speed = 4, bezier = "smoothOut", style = "fade" },
    { leaf = "fadeIn", speed = 3.4, bezier = "smoothOut" },
    { leaf = "fadeOut", speed = 2.6, bezier = "smoothOut" },
    { leaf = "workspaces", speed = 5, bezier = "smoothOut", style = "fade" },
    { leaf = "specialWorkspace", speed = 5, bezier = "smoothOut", style = "fade" },
}) do
    animation.enabled = not in_game
    hl.animation(animation)
end
