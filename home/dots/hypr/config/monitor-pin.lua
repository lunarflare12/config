-- NVIDIA connector names jump across boots (DP-1↔DP-4, HDMI-A-1↔HDMI-A-2).
-- Emit every alias; Hyprland ignores names that are not present this session.
local function pin()
    for _, m in ipairs({
        { output = "DP-1", mode = "2560x1080@200.00Hz", position = "0x0" },
        { output = "DP-4", mode = "2560x1080@200.00Hz", position = "0x0" },
        { output = "HDMI-A-1", mode = "1920x1080@60.00Hz", position = "2560x0" },
        { output = "HDMI-A-2", mode = "1920x1080@60.00Hz", position = "2560x0" },
    }) do
        hl.monitor({
            output = m.output,
            mode = m.mode,
            position = m.position,
            scale = 1,
            bitdepth = 8,
            disabled = false,
        })
    end
end

pin()
hl.on("monitor.added", pin)
hl.on("config.reloaded", pin)

-- Games on the ultrawide, workspace 8. Registered again on config.reloaded
-- so this handler runs after windows.lua (which used to pin workspace 4).
local GAME_WS = 8

local function game_window(w)
    if not w then
        return false
    end
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    local title = string.lower(tostring(w.title or w.initial_title or ""))
    if cls:find("steam_app_", 1, true) then
        return true
    end
    if cls:find("dota2", 1, true) or cls:find("gamescope", 1, true) then
        return true
    end
    if cls:find("overwatch", 1, true) or cls:find("albion", 1, true) then
        return true
    end
    if cls:find("minecraft", 1, true) then
        return true
    end
    if title:find("wine desktop", 1, true) or title:find("generals", 1, true) then
        return true
    end
    if title:find("minecraft", 1, true) and (cls == "" or cls:find("java", 1, true) or cls:find("glfw", 1, true)) then
        return true
    end
    return false
end

local function install_game_desk()
    if _G.aurora_games_ws8 then
        pcall(function()
            _G.aurora_games_ws8:remove()
        end)
    end
    _G.aurora_games_ws8 = hl.on("window.open", function(ev)
        local w = ev and (ev.window or ev) or nil
        if not game_window(w) then
            return
        end
        pcall(function()
            hl.dispatch(hl.dsp.window.move({ workspace = GAME_WS, window = w, silent = true }))
            hl.dispatch(hl.dsp.focus({ workspace = GAME_WS }))
        end)
    end)
end

install_game_desk()
hl.on("config.reloaded", install_game_desk)
