local home = os.getenv("HOME") or "/home/dd"
local game_flag = io.open(home .. "/.local/state/aurora-game", "r")
local in_game = game_flag ~= nil
if game_flag then
    game_flag:close()
end

hl.config({ animations = { enabled = not in_game } })

-- Native window open/close stay minimal. Keep a short fade so surfaces settle.
hl.curve("smoothOut", { type = "bezier", points = { { 0.16, 1 }, { 0.3, 1 } } })

hl.animation({ leaf = "borderangle", enabled = false })
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "windowsMove", enabled = false })
hl.animation({ leaf = "windowsIn", enabled = false })
hl.animation({ leaf = "windowsOut", enabled = false })

for _, animation in ipairs({
    { leaf = "layers", speed = 5, bezier = "smoothOut", style = "fade" },
    { leaf = "layersIn", speed = 4, bezier = "smoothOut", style = "fade" },
    { leaf = "fadeIn", speed = 4, bezier = "smoothOut" },
    { leaf = "fadeOut", speed = 4, bezier = "smoothOut" },
    { leaf = "workspaces", speed = 5, bezier = "smoothOut", style = "fade" },
    { leaf = "specialWorkspace", speed = 5, bezier = "smoothOut", style = "fade" },
}) do
    if animation.enabled == nil then
        animation.enabled = not in_game
    end
    hl.animation(animation)
end
