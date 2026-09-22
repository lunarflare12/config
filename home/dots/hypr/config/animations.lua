local game_flag = io.open("/home/dd/.local/state/aurora-game", "r")
local in_game = game_flag ~= nil
if game_flag then
    game_flag:close()
end

hl.config({ animations = { enabled = not in_game } })

-- Ease-out that actually uses 200Hz frames instead of snapping.
hl.curve("smoothOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })
hl.curve("smoothIn", { type = "bezier", points = { { 0.32, 0 }, { 0.67, 0 } } })

-- Continuous per-frame border work. With 200Hz + 60Hz that is free stutter.
hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "border", enabled = false })
-- YouTube / HTML5 FS is a windowsMove resize. popin only affects open/close;
-- this lerp is always a growing rectangle, so keep it off.
hl.animation({ leaf = "windowsMove", enabled = false })

for _, animation in ipairs({
    { leaf = "windows", speed = 4, bezier = "smoothOut", style = "popin 88%" },
    { leaf = "windowsIn", speed = 4, bezier = "smoothOut", style = "popin 88%" },
    { leaf = "windowsOut", speed = 4, bezier = "smoothIn", style = "popin 80%" },
    { leaf = "layers", speed = 5, bezier = "smoothOut", style = "fade" },
    { leaf = "layersIn", speed = 4, bezier = "smoothOut", style = "fade" },
    { leaf = "fade", speed = 4, bezier = "smoothOut" },
    { leaf = "workspaces", speed = 5, bezier = "smoothOut", style = "fade" },
    { leaf = "specialWorkspace", speed = 5, bezier = "smoothOut", style = "fade" },
}) do
    animation.enabled = not in_game
    hl.animation(animation)
end
