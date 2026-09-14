local programs = require("config/programs")
local mod = "SUPER"
local WS_PER = 10
local MONITORS = { "HDMI-A-1", "DP-1" }

local function cursor_monitor()
    return hl.get_monitor_at_cursor() or hl.get_active_monitor()
end

local function base_for_monitor(mon)
    if not mon then
        return 0
    end
    for i, name in ipairs(MONITORS) do
        if mon.name == name then
            return (i - 1) * WS_PER
        end
    end
    local ws = mon.active_workspace or hl.get_active_workspace(mon)
    if ws and ws.id then
        return math.floor((ws.id - 1) / WS_PER) * WS_PER
    end
    return 0
end

local function cursor_base()
    return base_for_monitor(cursor_monitor())
end

local function cursor_workspace_id()
    local mon = cursor_monitor()
    if mon then
        local ws = hl.get_active_workspace(mon) or mon.active_workspace
        if ws and ws.id then
            return ws.id
        end
    end
    local ws = hl.get_active_workspace()
    return (ws and ws.id) or 1
end

local function go_workspace(id)
    hl.dispatch(hl.dsp.focus({ workspace = id }))
end

hl.bind(mod .. " + Return", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(programs.browser))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(programs.file_manager))
hl.bind(mod .. " + R", hl.dsp.exec_cmd("qs ipc call launcher toggle"))
hl.bind(mod .. " + C", hl.dsp.exec_cmd("qs ipc call theme toggle"))
hl.bind(mod .. " + X", hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("qs ipc call clipboard toggle"))
hl.bind(mod .. " + Period", hl.dsp.exec_cmd("qs ipc call emoji toggle"))
hl.bind(mod .. " + TAB", hl.dsp.exec_cmd("qs ipc call overview toggle"))
hl.bind(mod .. " + UP", hl.dsp.exec_cmd("qs ipc call overview toggle"))
hl.bind(mod .. " + LEFT", function()
    local id = cursor_workspace_id()
    local base = math.floor((id - 1) / WS_PER) * WS_PER
    local local_n = ((id - 1) % WS_PER)
    go_workspace(base + ((local_n - 1) % WS_PER) + 1)
end)
hl.bind(mod .. " + RIGHT", function()
    local id = cursor_workspace_id()
    local base = math.floor((id - 1) / WS_PER) * WS_PER
    local local_n = ((id - 1) % WS_PER)
    go_workspace(base + ((local_n + 1) % WS_PER) + 1)
end)
hl.bind("PRINT", hl.dsp.exec_cmd(programs.scripts .. "/screenshot.sh output"))
hl.bind(mod .. " + SHIFT + S", hl.dsp.exec_cmd(programs.scripts .. "/screenshot.sh region"))
hl.bind(mod .. " + PRINT", hl.dsp.exec_cmd(programs.scripts .. "/screenshot.sh region"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("hyprpicker --autocopy"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(programs.scripts .. "/reload-hypr.sh"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd("qs ipc call theme toggle"))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd("qs ipc call shaders toggle"))
hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("F24", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

for key, direction in pairs({ h = "l", l = "r", j = "u", k = "d" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
end

for local_ws = 1, WS_PER do
    local key = local_ws % 10
    hl.bind(mod .. " + " .. key, function()
        go_workspace(cursor_base() + local_ws)
    end)
    hl.bind(mod .. " + SHIFT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = cursor_base() + local_ws }))
    end)
end

for key, direction in pairs({ H = "l", L = "r", K = "u", J = "d" }) do
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

for key, command in pairs({
    XF86AudioRaiseVolume = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
    XF86AudioLowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    XF86AudioMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    XF86AudioMicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    XF86MonBrightnessUp = "brightnessctl set +2%",
    XF86MonBrightnessDown = "brightnessctl set 2%-",
}) do
    hl.bind(key, hl.dsp.exec_cmd(command), { locked = true, repeating = true })
end

for key, command in pairs({
    XF86AudioNext = "playerctl next",
    XF86AudioPause = "playerctl play-pause",
    XF86AudioPlay = "playerctl play-pause",
    XF86AudioPrev = "playerctl previous",
}) do
    hl.bind(key, hl.dsp.exec_cmd(command), { locked = true })
end
