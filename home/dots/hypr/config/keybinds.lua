local ok_programs, programs = pcall(require, "config/programs")
if not ok_programs or type(programs) ~= "table" then
    programs = {
        terminal = "kitty",
        browser = (os.getenv("HOME") or "/home/dd") .. "/.config/scripts/google-chrome.sh",
        file_manager = (os.getenv("HOME") or "/home/dd") .. "/.config/scripts/finder.sh",
        scripts = (os.getenv("HOME") or "/home/dd") .. "/.config/scripts",
    }
end
local mod = "SUPER"
local WS_PER = 12
local WS_KEYS = { "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "minus", "equal" }
local MONITORS = { "DP-1", "HDMI-A-1" }

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
hl.bind(mod .. " + T", hl.dsp.exec_cmd(programs.terminal))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(programs.browser))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(programs.scripts .. "/finder.sh"))
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
hl.bind(mod .. " + S", hl.dsp.exec_cmd("qs ipc call screenshot toggle"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("hyprpicker --autocopy"))
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.kill())
hl.bind(mod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle", layout_aware = false }))
hl.bind(mod .. " + SHIFT + R", hl.dsp.exec_cmd(programs.scripts .. "/reload-hypr.sh"))
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd("qs ipc call shaders toggle"))
hl.bind(mod .. " + ALT + L", hl.dsp.exec_cmd("qs ipc call lock lock"))
hl.bind("F24", hl.dsp.exec_cmd("hyprctl switchxkblayout all next"))

for key, direction in pairs({ h = "l", l = "r", j = "u", k = "d" }) do
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ direction = direction }))
end

for local_ws, key in ipairs(WS_KEYS) do
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
hl.bind(mod .. " + mouse_down", hl.dsp.exec_cmd("qs ipc call island next"))
hl.bind(mod .. " + mouse_up", hl.dsp.exec_cmd("qs ipc call island prev"))

for key, command in pairs({
    XF86AudioRaiseVolume = "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+",
    XF86AudioLowerVolume = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-",
    XF86AudioMute = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle",
    XF86AudioMicMute = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle",
    XF86MonBrightnessUp = "qs ipc call brightness up",
    XF86MonBrightnessDown = "qs ipc call brightness down",
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

local opencluely = (os.getenv("HOME") or "") .. "/projects/opencluely/opencluely"
hl.bind("CTRL + SHIFT + S", hl.dsp.exec_cmd(opencluely .. " shortcut screenshot"))
hl.bind("CTRL + SHIFT + O", hl.dsp.exec_cmd(opencluely .. " shortcut toggle"))
hl.bind("CTRL + SHIFT + I", hl.dsp.exec_cmd(opencluely .. " shortcut interactive"))
hl.bind("CTRL + SHIFT + Y", hl.dsp.exec_cmd(opencluely .. " shortcut show"))
hl.bind("CTRL + SHIFT + backslash", hl.dsp.exec_cmd(opencluely .. " shortcut reset"))
hl.bind("ALT + A", hl.dsp.exec_cmd(opencluely .. " shortcut interactive"))
hl.bind("ALT + R", hl.dsp.exec_cmd(opencluely .. " shortcut mic"))
hl.bind("CTRL + comma", hl.dsp.exec_cmd(opencluely .. " shortcut settings"))
