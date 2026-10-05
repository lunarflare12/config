local GAME_MONITOR = "DP-1"
-- Local 4 on the ultrawide (DP owns 1-12, HDMI owns 13-24).
-- Ultrawide (DP-1 / DP-4) owns workspaces 1–12. Games land on 8.
local GAME_WORKSPACE = 8
-- Native Dota 2 is class dota2, not steam_app_570.
local GAME_CLASS = "^(steam_app_|dota2|[Mm]inecraft)"
-- Nix wraps the binary as .gamescope-wrapped; class match is whole-string.
local GAMESCOPE_CLASS = ".*gamescope.*"
local ALL_GAME_CLASS = "^(steam_app_|dota2|.*gamescope.*|[Mm]inecraft)"

-- Swallow maximize for tiled clients. Chromium echoes set_maximized after
-- HTML5 FS exit; honoring it leaves the window maximized in the workarea.
-- YouTube `f` is xdg fullscreen (client=2), not maximize — do not exclude
-- browsers here or that echo fights exclusive FS.
hl.window_rule({
    name = "suppress-maximize",
    match = { class = "negative:^(steam_app_|dota2|.*gamescope.*|[Mm]inecraft|steam)$" },
    suppress_event = "maximize",
})

-- CSD/X11 titlebar moves otherwise drag windows without Super.
-- Super+LMB (keybinds) still starts an interactive move.
hl.window_rule({
    name = "super-only-move",
    match = { class = ".*" },
    suppress_event = "move",
})

for _, rule in ipairs({
    -- Never render_unfocused here: with OW FS on the ultrawide, Electron
    -- (Cursor/Obsidian/Discord) keeps compositing underneath and hitchs the game.
    { name = "opaque-discord", match = { class = "^([Dd]iscord|vesktop)$" }, opaque = true, no_blur = true },
    -- HTML5 `f` is client FS (2) while dwindle's layout-aware handler keeps
    -- internal=0 (player stays in the bar/dock tile). sync + immediate + no
    -- ICCCM max size so the lua promoter can set internal=2 covering the output.
    -- chrome-dd / chrome-az / chrome-hika are the container browsers.
    -- no_anim stays off so open/close still pop; windowsMove is already off
    -- so HTML5 fullscreen does not grow as a rectangle.
    { name = "browser-sync-fs", match = { class = "^(google-chrome|chrome|chrome-dd|chrome-az|chrome-hika|chrome-sciencesoft|firefox|zen)$" }, sync_fullscreen = true, no_max_size = true, immediate = true, idle_inhibit = "fullscreen" },
    { name = "player-sync-fs", match = { class = "^(mpv|vlc|celluloid)$" }, sync_fullscreen = true, no_anim = true, no_max_size = true, immediate = true, idle_inhibit = "fullscreen" },
    { name = "opaque-cursor", match = { class = "^(cursor)$" }, opaque = true, no_blur = true },
    { name = "opaque-code", match = { class = "^(code|Code)$" }, opaque = true, no_blur = true },
    { name = "opaque-obsidian", match = { class = "^(obsidian)$" }, opaque = true, no_blur = true },
    -- Steam CEF at 1x. Do not render_unfocused: GameMode then composites
    -- Steam on the CPU.
    { name = "steam-cef", match = { class = "^(steam)$", title = "^(Steam)$" }, opaque = true, no_blur = true, no_max_size = true, tile = true, suppress_event = "maximize" },
    { name = "steam-chrome", match = { class = "^(steam)$" }, opaque = true, no_blur = true },
    { name = "steam-menus", match = { class = "^(steam)$", title = "^\\s*$" }, float = true, stay_focused = true, no_initial_focus = true, no_follow_mouse = true, min_size = { 1, 1 }, no_anim = true, border_size = 0, rounding = 0, decorate = false, opaque = true, no_blur = true },
    { name = "steam-dialogs", match = { class = "^(steam)$", title = "negative:^(Steam)$" }, float = true, stay_focused = true, no_anim = true, no_initial_focus = true, no_follow_mouse = true, border_size = 0, rounding = 0, decorate = false, opaque = true, no_blur = true },
    { name = "steam-login", match = { class = "^(steam)$", title = "^(Sign in to Steam)$" }, float = true, center = true, size = "780 520" },
    { name = "steam-x11", match = { class = "^$", title = "^(Steam.*)$", xwayland = true }, opaque = true, no_blur = true, float = true, center = true },
    { name = "float-media", match = { title = "^(imv|mpv|danmufloat|termfloat|nemo|ncmpcpp)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-waydroid", match = { class = "^(Waydroid)$" }, float = true, size = "1280 720", center = true },
    { name = "float-insta360", match = { class = "^(insta360linkgui)$" }, float = true, size = "1760 1000", center = true },
    { name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol-qt)$" }, float = true },
    { name = "float-satty", match = { class = "^(com.gabm.satty|satty)$" }, float = true, center = true, no_anim = true, pin = true, immediate = true, opaque = true, no_blur = true },
    { name = "float-picture-in-picture", match = { class = "^()$", title = "^(Picture in picture)$" }, float = true },
    { name = "float-save-file", match = { class = "^()$", title = "^(Save File)$" }, float = true },
    { name = "float-open-file", match = { class = "^()$", title = "^(Open File)$" }, float = true },
    { name = "float-zen-pip", match = { class = "^(ZenBrowser)$", title = "^(Picture-in-Picture)$" }, float = true },
    { name = "float-blueman", match = { class = "^(blueman-manager)$" }, float = true },
    { name = "float-bitwarden", match = { class = "^(chrome-nngceckbapebfimnlniiiahkandclblb-Default)$" }, float = true },
    { name = "float-xdg-portal", match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$" }, float = true },
    { name = "float-termfloat", match = { class = "^(termfloat)$" }, float = true, center = true, size = "520 220" },
    { name = "float-sysupdate", match = { class = "^(sysupdate)$" }, float = true, center = true, size = "920 560" },
    { name = "float-zenity", match = { class = "^(zenity)$" }, float = true },
    { name = "float-steam-updater", match = { class = "^()$", title = "^(Steam - Self Updater)$" }, float = true },
    { name = "float-dell-controller", match = { class = "^(python3)$", title = "^(Dell G Series Controller)$" }, float = true },
    { name = "finder-pick-bar", match = { class = "^(finder-pick)$", title = "^(Select Folder)$" }, float = true, pin = true, rounding = 16, border_size = 0, size = "560 80", center = true, opaque = false },
    { name = "finder-pick", match = { class = "^(finder-pick)$" }, float = true, rounding = 20, border_size = 0, size = "980 640", center = true, opaque = false },
    { name = "finder-menus", match = { class = "^(thunar|Thunar)$", title = "^$" }, float = true, rounding = 14, border_size = 0, no_anim = true, decorate = false, no_initial_focus = true, opaque = false },
    { name = "finder-main", match = { class = "^(thunar|Thunar)$", title = ".+" }, float = true, rounding = 20, border_size = 0, size = "1180 740", opaque = false },
    { name = "float-thunar-rename", match = { class = "^(thunar|Thunar)$", title = "^(Rename.*)$" }, float = true, size = "500 200", center = true },
    { name = "float-thunar-progress", match = { class = "^(thunar|Thunar)$", title = "^(File Operation Progress)$" }, float = true, center = true },
    { name = "float-thunar-confirm", match = { class = "^(thunar|Thunar)$", title = "^(Confirm.*)$" }, float = true, center = true },
    { name = "float-thunar-question", match = { class = "^(thunar|Thunar)$", title = "^(Question)$" }, float = true, center = true },
    { name = "float-thunar-create", match = { class = "^(thunar|Thunar)$", title = "^(Create.*)$" }, float = true, center = true },
    { name = "float-thunar-properties", match = { class = "^(thunar|Thunar)$", title = "^(.*Properties)$" }, float = true, size = "600 500", center = true },
    { name = "float-opencluely", match = { title = "^OpenCluely$" }, float = true, pin = true, size = "520 680", center = true, no_anim = true },
    -- Keep guests inside the blue frame. Exclusive FS hides the chrome.
    { name = "virt-viewer", match = { class = "^(virt-viewer|Virt-viewer|remote-viewer|org\\.virt-manager\\.virt-viewer|looking-glass-client)$" }, tile = true, sync_fullscreen = true, no_max_size = true, opaque = true, no_blur = true, rounding = 16 },
}) do
    hl.window_rule(rule)
end

-- Pin games to the ultrawide. Internal maximize + client fullscreen: the game
-- thinks it is exclusive FS (raw mouse, no bar). sync_fullscreen must stay
-- off or this collapses back to real exclusive and NVIDIA direct_scanout
-- blanks the other output.
-- Do not set move/size here: that tiles the window under the bar and kills FS.
local function game_rule(name, match, extra)
    local rule = {
        name = name,
        match = match,
        fullscreen_state = "1 2",
        sync_fullscreen = false,
        content = "game",
        immediate = true,
        no_anim = true,
        no_blur = true,
        opaque = true,
        force_rgbx = true,
        decorate = false,
        rounding = 0,
        border_size = 0,
        idle_inhibit = "fullscreen",
        render_unfocused = true,
        focus_on_activate = true,
        no_auto_hdr = true,
    }
    if extra then
        for k, v in pairs(extra) do
            rule[k] = v
        end
    end
    hl.window_rule(rule)
end

game_rule("games-class", { class = GAME_CLASS }, { confine_pointer = true })
game_rule("gamescope-class", { class = GAMESCOPE_CLASS }, { confine_pointer = false, no_vrr = true })
game_rule("games-initial-class", { initial_class = GAME_CLASS }, { confine_pointer = true })
game_rule("gamescope-initial-class", { initial_class = GAMESCOPE_CLASS }, { confine_pointer = false, no_vrr = true })

-- Client stays windowed (0) so OW keeps a 1920×16:9 buffer. Internal
-- exclusive stretches it. Client=2 makes the game pick 2560 21:9.
local OVERWATCH_CLASS = "^steam_app_2357570$"
game_rule("overwatch-class", { class = OVERWATCH_CLASS }, {
    fullscreen_state = "2 0",
    no_max_size = true,
})
game_rule("overwatch-initial-class", { initial_class = OVERWATCH_CLASS }, {
    fullscreen_state = "2 0",
    no_max_size = true,
})

-- Albion 2FA/login: Unity Input System drops text in exclusive FS.
-- Confine also eats the click that focuses the code field.
local ALBION_CLASS = "^(steam_app_761890|[Aa]lbion)"
game_rule("albion-class", { class = ALBION_CLASS }, {
    confine_pointer = false,
    fullscreen_state = "1 0",
    no_max_size = true,
    suppress_event = "x11configurerequest",
})
game_rule("albion-initial-class", { initial_class = ALBION_CLASS }, {
    confine_pointer = false,
    fullscreen_state = "1 0",
    no_max_size = true,
    suppress_event = "x11configurerequest",
})

local function window_class(w)
    return string.lower(tostring(w and (w.initial_class or "") or "") .. " " .. tostring(w and (w.class or "") or ""))
end

local function same_game_count(w)
    local n = 0
    local cls = window_class(w)
    local ok, wins = pcall(function()
        return hl.get_windows()
    end)
    if not ok or type(wins) ~= "table" then
        return 1
    end
    for _, x in ipairs(wins) do
        if window_class(x) == cls or (cls ~= "" and window_class(x):find(cls, 1, true)) then
            n = n + 1
        end
    end
    return n
end

local function pin_game(w, client_fs, internal_fs)
    local steal = same_game_count(w) <= 1
    local cls = window_class(w)
    -- Shade plugin remaps the cursor on tagged windows. Strip before FS.
    if cls:find("steam_app_2357570", 1, true) then
        pcall(function()
            hl.exec_cmd((os.getenv("HOME") or "/home/dd") .. "/.config/scripts/hypr-window-shade.sh unload")
        end)
        pcall(function()
            local home = os.getenv("HOME") or "/home/dd"
            local open = home .. "/.config/hypr/shaders/liixini/crosshatch/open.glsl"
            local close = home .. "/.config/hypr/shaders/liixini/crosshatch/close.glsl"
            hl.window_rule({
                name = "ow-strip-shader-open",
                match = { class = "^steam_app_2357570$" },
                tag = "-shader_open:" .. open,
            })
            hl.window_rule({
                name = "ow-strip-shader-close",
                match = { class = "^steam_app_2357570$" },
                tag = "-shader_close:" .. close,
            })
        end)
    end
    pcall(function()
        hl.dispatch(hl.dsp.window.move({ workspace = GAME_WORKSPACE, window = w, silent = true }))
    end)
    -- First map only. Later Wine/activate remaps must not steal the desktop.
    if steal then
        pcall(function()
            hl.dispatch(hl.dsp.focus({ workspace = GAME_WORKSPACE }))
        end)
    end
    pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state({
            window = w,
            internal = internal_fs or 1,
            client = client_fs,
        }))
    end)
    -- Native titles (Dota 2) never talk to gamemoded. Still drop blur/anim.
    pcall(function()
        hl.exec_cmd((os.getenv("HOME") or "/home/dd") .. "/.config/scripts/gamemode-start.sh")
    end)
end

local function steam_menu_window(w)
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    if cls:find("steam_app_", 1, true) then
        return false
    end
    if not cls:find("steam", 1, true) then
        return false
    end
    local title = tostring(w.title or w.initial_title or ""):gsub("^%s+", ""):gsub("%s+$", "")
    if title == "Steam" then
        return false
    end
    pcall(function()
        hl.dispatch(hl.dsp.window.float({ window = w, action = "on" }))
    end)
    return true
end

local function game_to_desk(win)
    if not win then
        return
    end
    local w = win.window or win
    if steam_menu_window(w) then
        return
    end
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    local title = string.lower(tostring(w.title or ""))
    -- Nested gamescope first. Do not listen to window.fullscreen —
    -- re-dispatching there fights 1 2 vs 1 0.
    if cls:find("gamescope", 1, true) then
        pin_game(w, 2)
        return
    end
    if cls:find("steam_app_761890", 1, true) or cls:find("albion", 1, true) then
        pin_game(w, 0)
        return
    end
    if cls:find("prism", 1, true) then
        return
    end
    if cls:find("steam_app_2357570", 1, true) then
        pin_game(w, 0, 2)
        return
    end
    if cls:find("steam_app_", 1, true) or cls:find("dota2", 1, true) or cls:find("minecraft", 1, true) then
        pin_game(w, 2)
        return
    end
    if title:find("minecraft", 1, true) and (cls == "" or cls:find("java", 1, true) or cls:find("lwjgl", 1, true) or cls:find("glfw", 1, true)) then
        pin_game(w, 2)
    end
end

if _G.aurora_satty_open then
    pcall(function()
        _G.aurora_satty_open:remove()
    end)
    _G.aurora_satty_open = nil
end

if _G.aurora_game_open then
    pcall(function()
        _G.aurora_game_open:remove()
    end)
end
_G.aurora_game_open = hl.on("window.open", game_to_desk)
if _G.aurora_game_open_early then
    pcall(function()
        _G.aurora_game_open_early:remove()
    end)
end
pcall(function()
    _G.aurora_game_open_early = hl.on("window.open_early", game_to_desk)
end)

local function pin_launch(win)
    local w = win and (win.window or win) or nil
    if not w then
        return
    end
    local f = io.open((os.getenv("HOME") or "/home/dd") .. "/.local/state/aurora-launch", "r")
    if not f then
        return
    end
    local body = f:read("*a") or ""
    f:close()
    local ws, rest = body:match("^(%d+)%s+(%S+)")
    ws = tonumber(ws)
    if not ws or not rest or rest == "" then
        return
    end
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or "") .. " " .. tostring(w.title or w.initial_title or ""))
    if cls:find("steam_app_", 1, true) or cls:find("gamescope", 1, true) or cls:find("quickshell", 1, true) then
        return
    end
    local hit = false
    for raw in string.gmatch(rest, "[^,]+") do
        local needle = string.lower(raw)
        if needle ~= "" and #needle >= 2 and cls:find(needle, 1, true) then
            hit = true
            break
        end
    end
    if not hit then
        return
    end
    pcall(function()
        hl.dispatch(hl.dsp.window.move({ workspace = ws, window = w, silent = true }))
    end)
end

if _G.aurora_launch_open then
    pcall(function()
        _G.aurora_launch_open:remove()
    end)
end
_G.aurora_launch_open = hl.on("window.open", pin_launch)
if _G.aurora_launch_open_early then
    pcall(function()
        _G.aurora_launch_open_early:remove()
    end)
end
pcall(function()
    _G.aurora_launch_open_early = hl.on("window.open_early", pin_launch)
end)
if _G.aurora_game_fs then
    pcall(function()
        _G.aurora_game_fs:remove()
    end)
    _G.aurora_game_fs = nil
end

local function is_game_focus(w)
    if not w then
        return false
    end
    local cls = window_class(w)
    if cls:find("steam", 1, true) and not cls:find("steam_app_", 1, true) then
        return false
    end
    return cls:find("steam_app_", 1, true)
        or cls:find("albion", 1, true)
        or cls:find("dota2", 1, true)
        or cls:find("gamescope", 1, true)
        or cls:find("minecraft", 1, true)
end

local function ow_mapped()
    local ok, wins = pcall(function()
        return hl.get_windows()
    end)
    if not ok or type(wins) ~= "table" then
        return false
    end
    for i = 1, #wins do
        local x = wins[i]
        if x and window_class(x):find("steam_app_2357570", 1, true) then
            return true
        end
    end
    return false
end

_G.aurora_sync_texture_expand = function(win)
    local w = win and (win.window or win) or hl.get_active_window()
    -- Keep nearest/expand for the whole OW map. Focus blips were flipping
    -- blur+bilinear back on — that is why the picture never changed.
    local ingame = is_game_focus(w)
    local light = ingame
    local hide_bar = ingame
    if _G.aurora_compositor_light == light then
        return
    end
    _G.aurora_compositor_light = light
    pcall(function()
        hl.config({
            animations = { enabled = not light },
            decoration = {
                rounding = light and 0 or 16,
                blur = { enabled = not light },
                shadow = { enabled = not light },
            },
            general = {
                border_size = light and 0 or 2,
                gaps_in = light and 0 or 6,
                gaps_out = light and 0 or { top = 7, right = 10, bottom = 10, left = 10 },
            },
            render = {
                expand_undersized_textures = light,
                send_content_type = light,
            },
            xwayland = {
                use_nearest_neighbor = false,
            },
            misc = {
                mouse_move_focuses_monitor = true,
                render_unfocused_fps = 15,
            },
            debug = {
                render_solitary_wo_damage = false,
            },
        })
    end)
    if light then
        hl.exec_cmd("pkill -STOP -x cava >/dev/null 2>&1 || true")
        hl.exec_cmd("pkill -STOP -x quickshell >/dev/null 2>&1 || true")
        -- Kill by PID only: pkill -f matches the hyprctl/eval cmdline and self-kills.
        hl.exec_cmd("for p in $(pgrep -f '/aurora fossilize loop' || true); do kill -STOP \"$p\" 2>/dev/null || true; done")
        hl.exec_cmd("pid=$(pgrep -x awww-daemon | head -1); [ -n \"$pid\" ] && kill -STOP \"$pid\" || true")
    else
        hl.exec_cmd("pkill -CONT -x cava >/dev/null 2>&1 || true")
        hl.exec_cmd("pkill -CONT -x quickshell >/dev/null 2>&1 || true")
        hl.exec_cmd("for p in $(pgrep -f '/aurora fossilize loop' || true); do kill -CONT \"$p\" 2>/dev/null || true; done")
        hl.exec_cmd("pid=$(pgrep -x awww-daemon | head -1); [ -n \"$pid\" ] && kill -CONT \"$pid\" || true")
    end
    hl.exec_cmd(hide_bar and "qs ipc call bar hide" or "qs ipc call bar show")
end

local function aurora_restore_desktop()
    if is_game_focus(hl.get_active_window()) then
        return
    end
    _G.aurora_compositor_light = false
    pcall(function()
        hl.config({
            animations = { enabled = true },
            decoration = {
                rounding = 16,
                blur = { enabled = true },
                shadow = { enabled = true },
            },
            general = {
                border_size = 2,
                gaps_in = 6,
                gaps_out = { top = 7, right = 10, bottom = 10, left = 10 },
            },
            render = {
                expand_undersized_textures = false,
                send_content_type = false,
            },
            misc = {
                mouse_move_focuses_monitor = true,
                render_unfocused_fps = 15,
            },
            xwayland = {
                use_nearest_neighbor = false,
            },
        })
    end)
    hl.exec_cmd("qs ipc call bar show")
    hl.exec_cmd("pkill -CONT -x cava >/dev/null 2>&1 || true")
    hl.exec_cmd("pkill -CONT -x quickshell >/dev/null 2>&1 || true")
    hl.exec_cmd("for p in $(pgrep -f '/aurora fossilize loop' || true); do kill -CONT \"$p\" 2>/dev/null || true; done")
    hl.exec_cmd("pid=$(pgrep -x awww-daemon | head -1); [ -n \"$pid\" ] && kill -CONT \"$pid\" || true")
    -- Shade was unloaded for OW; bring open/close GLSL back on the desktop.
    hl.exec_cmd((os.getenv("HOME") or "/home/dd") .. "/.config/scripts/hypr-window-shade.sh load")
end

local function find_outputs()
    local ok, mons = pcall(function()
        if hl.get_monitors then
            return hl.get_monitors()
        end
        return {}
    end)
    if not ok or type(mons) ~= "table" then
        return nil, nil
    end
    local hdmi, dp
    for _, m in ipairs(mons) do
        local n = tostring(m.name or m.output or "")
        local desc = tostring(m.description or m.desc or m.model or "")
        if n == "HDMI-A-2" or n == "HDMI-A-1" or desc:find("PHL", 1, true) or desc:find("Philips", 1, true) then
            hdmi = m
        elseif n == "DP-4" or n == "DP-1" or desc:find("Mi 30", 1, true) or desc:find("Xiaomi", 1, true) then
            dp = m
        end
    end
    return hdmi, dp
end

local function output_ok()
    local hdmi, dp = find_outputs()
    if not hdmi or not dp then
        return false
    end
    local function n(v)
        return tonumber(v) or 0
    end
    local hrate = n(hdmi.refresh or hdmi.refresh_rate or hdmi.refreshRate)
    local drate = n(dp.refresh or dp.refresh_rate or dp.refreshRate)
    return n(hdmi.width) == 1920
        and n(hdmi.height) == 1080
        and math.abs(hrate - 60) < 1.5
        and n(hdmi.x) == 2560
        and n(dp.width) == 2560
        and n(dp.height) == 1080
        and math.abs(drate - 200) < 2
        and n(dp.x) == 0
end

local function pin_outputs()
    if output_ok() then
        return
    end
    local hdmi, dp = find_outputs()
    local dp_name = (dp and (dp.name or dp.output)) or "DP-1"
    local hdmi_name = (hdmi and (hdmi.name or hdmi.output)) or "HDMI-A-1"
    pcall(function()
        hl.monitor({
            output = tostring(dp_name),
            mode = "2560x1080@200.00Hz",
            position = "0x0",
            scale = 1,
            bitdepth = 8,
            disabled = false,
        })
        hl.monitor({
            output = tostring(hdmi_name),
            mode = "1920x1080@60.00Hz",
            position = "2560x0",
            scale = 1,
            bitdepth = 8,
            disabled = false,
        })
    end)
end

if _G.aurora_tex_expand then
    pcall(function()
        _G.aurora_tex_expand:remove()
    end)
end
_G.aurora_tex_expand = hl.on("window.active", function(ev)
    _G.aurora_sync_texture_expand(ev)
end)

if _G.aurora_game_close then
    pcall(function()
        _G.aurora_game_close:remove()
    end)
end
_G.aurora_game_close = hl.on("window.close", function(ev)
    local w = ev and (ev.window or ev) or nil
    if is_game_focus(w) or not is_game_focus(hl.get_active_window()) then
        if not is_game_focus(hl.get_active_window()) then
            aurora_restore_desktop()
        else
            _G.aurora_sync_texture_expand()
        end
    end
end)

-- Drop leftover handlers from prior config loads (names split to avoid stale refs).
do
    local p = "aurora_" .. "ow_"
    for _, suf in ipairs({
        "plugin_open", "plugin_close", "desktop_watch",
        "fs", "fs_active", "fs_open", "fs_focus", "mon",
    }) do
        local key = p .. suf
        if _G[key] then
            pcall(function()
                _G[key]:remove()
            end)
            _G[key] = nil
        end
    end
    _G[p .. "plugin_loaded"] = nil
end

_G.aurora_sync_texture_expand()

local function is_media_window(w)
    if not w then
        return false
    end
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    return cls:find("google-chrome", 1, true)
        or cls:find("chrome-dd", 1, true)
        or cls:find("chrome-az", 1, true)
        or cls:find("chrome-hika", 1, true)
        or cls:find("chrome-sciencesoft", 1, true)
        or cls:find("firefox", 1, true)
        or cls:find("zen", 1, true)
        or cls == "chrome"
        or cls:find("mpv", 1, true)
        or cls:find("vlc", 1, true)
        or cls:find("celluloid", 1, true)
end

-- Dwindle layout-aware FS keeps the window tiled and only tells the client
-- it is fullscreen (internal=0, client=2). That is the YouTube-in-the-tile
-- look with bar/dock still reserved. Force the default handler so internal
-- is FSMODE_FULLSCREEN and the surface covers the output including zones.
local media_fs_busy = {}

local function media_fs_mode(w)
    local internal = tonumber(w.fullscreen) or 0
    local client = tonumber(w.fullscreen_client) or 0
    return internal, client
end

local function promote_media_fs(w)
    w = w and (w.window or w) or nil
    if not is_media_window(w) then
        return
    end
    local addr = tostring(w.address or "")
    if addr == "" or media_fs_busy[addr] then
        return
    end
    local internal, client = media_fs_mode(w)
    if client < 2 or internal >= 2 then
        return
    end
    media_fs_busy[addr] = true
    pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state({
            window = w,
            internal = 2,
            client = 2,
            action = "set",
            layout_aware = false,
        }))
    end)
    media_fs_busy[addr] = nil
end

-- Wine re-maps the surface on every alt-tab and Hyprland falls back to
-- maximize. Maximize honours the bar band, so the cursor desyncs again.
local ow_fs_busy = {}

local function ow_live_fs(w)
    local fs = tonumber(w.fullscreen) or 0
    local fsc = tonumber(w.fullscreen_client or w.fullscreenClient)
    if fsc ~= nil then
        return fs, fsc
    end
    local addr = tostring(w.address or "")
    local ok, wins = pcall(function()
        return hl.get_windows()
    end)
    if ok and type(wins) == "table" then
        for i = 1, #wins do
            local x = wins[i]
            if x and tostring(x.address or "") == addr then
                return tonumber(x.fullscreen) or fs, tonumber(x.fullscreen_client or x.fullscreenClient or 0) or 0
            end
        end
    end
    return fs, -1
end

local function keep_overwatch_exclusive(w)
    w = w and (w.window or w) or nil
    if not w then
        return
    end
    if not window_class(w):find("steam_app_2357570", 1, true) then
        return
    end
    local addr = tostring(w.address or "")
    if addr == "" or ow_fs_busy[addr] then
        return
    end
    local fs, fsc = ow_live_fs(w)
    if fs >= 2 and fsc == 0 then
        return
    end
    ow_fs_busy[addr] = true
    pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state({
            window = w,
            internal = 2,
            client = 0,
            action = "set",
            layout_aware = false,
        }))
    end)
    pcall(function()
        if _G.aurora_sync_texture_expand then
            _G.aurora_sync_texture_expand(w)
        end
    end)
    ow_fs_busy[addr] = nil
end

for _, slot in ipairs({ "aurora_ow_fs", "aurora_ow_fs_active" }) do
    if _G[slot] then
        pcall(function()
            _G[slot]:remove()
        end)
        _G[slot] = nil
    end
end
_G.aurora_ow_fs = hl.on("window.fullscreen", keep_overwatch_exclusive)
_G.aurora_ow_fs_active = hl.on("window.active", keep_overwatch_exclusive)

if _G.aurora_media_fs then
    pcall(function()
        _G.aurora_media_fs:remove()
    end)
end
_G.aurora_media_fs = hl.on("window.fullscreen", promote_media_fs)
if _G.aurora_media_fs_active then
    pcall(function()
        _G.aurora_media_fs_active:remove()
    end)
end
_G.aurora_media_fs_active = hl.on("window.active", promote_media_fs)

if _G.aurora_monitor_pin then
    pcall(function()
        _G.aurora_monitor_pin:remove()
    end)
end
_G.aurora_monitor_pin = hl.on("monitor.added", function()
    pin_outputs()
end)

-- Re-apply 16:9 vkfix after hypr reload (preReload clears the app list).
local vkfix = (os.getenv("HOME") or "/home/dd") .. "/.config/scripts/hypr-csgo-vulkan-fix.sh"
if _G.aurora_vkfix_cfg then
    pcall(function()
        _G.aurora_vkfix_cfg:remove()
    end)
end
_G.aurora_vkfix_cfg = hl.on("config.reloaded", function()
    hl.exec_cmd(vkfix .. " reload")
end)
hl.exec_cmd(vkfix .. " ensure")
