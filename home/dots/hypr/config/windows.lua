local GAME_WORKSPACE = 8
local GAME_CLASS = "^(steam_app_|dota2|[Mm]inecraft)"
local GAMESCOPE_CLASS = ".*gamescope.*"
local ALBION_CLASS = "^(steam_app_761890|[Aa]lbion)"

-- Chromium после HTML5 FS шлёт maximize — глушим, иначе окно залипает в workarea.
hl.window_rule({
    name = "suppress-maximize",
    match = { class = "negative:^(steam_app_|dota2|.*gamescope.*|[Mm]inecraft|steam)$" },
    suppress_event = "maximize",
})

-- Перетаскивание только через Super+LMB (см. keybinds).
hl.window_rule({
    name = "super-only-move",
    match = { class = ".*" },
    suppress_event = "move",
})

for _, rule in ipairs({
    { name = "opaque-discord", match = { class = "^([Dd]iscord|vesktop)$" }, opaque = true, no_blur = true },
    { name = "browser-sync-fs", match = { class = "^(google-chrome|chrome|chrome-dd|chrome-az|chrome-hika|chrome-sciencesoft|firefox|zen)$" }, sync_fullscreen = true, no_max_size = true, immediate = true, idle_inhibit = "fullscreen" },
    { name = "player-sync-fs", match = { class = "^(mpv|vlc|celluloid)$" }, sync_fullscreen = true, no_anim = true, no_max_size = true, immediate = true, idle_inhibit = "fullscreen" },
    { name = "opaque-cursor", match = { class = "^(cursor)$" }, opaque = true, no_blur = true },
    { name = "opaque-code", match = { class = "^(code|Code)$" }, opaque = true, no_blur = true },
    { name = "opaque-obsidian", match = { class = "^(obsidian)$" }, opaque = true, no_blur = true },
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
    { name = "virt-viewer", match = { class = "^(virt-viewer|Virt-viewer|remote-viewer|org\\.virt-manager\\.virt-viewer|looking-glass-client)$" }, tile = true, sync_fullscreen = true, no_max_size = true, opaque = true, no_blur = true, rounding = 16 },
}) do
    hl.window_rule(rule)
end

-- Игры на ультраширокий: internal maximize + client FS. sync_fullscreen=off,
-- иначе exclusive FS и NVIDIA blankит второй монитор.
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

-- Albion 2FA: в exclusive FS Unity глотает ввод; confine ломает клик по полю кода.
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
    pcall(function()
        hl.dispatch(hl.dsp.window.move({ workspace = GAME_WORKSPACE, window = w, silent = true }))
    end)
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
end

local function steam_menu_window(w)
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    if cls:find("steam_app_", 1, true) or not cls:find("steam", 1, true) then
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
    if cls:find("steam_app_", 1, true) or cls:find("dota2", 1, true) or cls:find("minecraft", 1, true) then
        pin_game(w, 2)
        return
    end
    if title:find("minecraft", 1, true) and (cls == "" or cls:find("java", 1, true) or cls:find("lwjgl", 1, true) or cls:find("glfw", 1, true)) then
        pin_game(w, 2)
    end
end

local function rebind(slot, event, fn)
    if _G[slot] then
        pcall(function()
            _G[slot]:remove()
        end)
    end
    _G[slot] = hl.on(event, fn)
end

rebind("aurora_game_open", "window.open", game_to_desk)
pcall(function()
    rebind("aurora_game_open_early", "window.open_early", game_to_desk)
end)

-- Закрепить окно на workspace из ~/.local/state/aurora-launch («ws class…»).
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

rebind("aurora_launch_open", "window.open", pin_launch)
pcall(function()
    rebind("aurora_launch_open_early", "window.open_early", pin_launch)
end)

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

-- Лёгкий композитор в игре: без blur/анимаций, стоп cava/обоев.
_G.aurora_sync_texture_expand = function(win)
    local w = win and (win.window or win) or hl.get_active_window()
    local light = is_game_focus(w)
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
            xwayland = { use_nearest_neighbor = false },
            misc = {
                mouse_move_focuses_monitor = true,
                render_unfocused_fps = 15,
            },
        })
    end)
    if light then
        hl.exec_cmd("pkill -STOP -x cava >/dev/null 2>&1 || true")
        hl.exec_cmd("for p in $(pgrep -f '/aurora fossilize loop' || true); do kill -STOP \"$p\" 2>/dev/null || true; done")
        hl.exec_cmd("pid=$(pgrep -x awww-daemon | head -1); [ -n \"$pid\" ] && kill -STOP \"$pid\" || true")
        hl.exec_cmd("qs ipc call bar hide")
    else
        hl.exec_cmd("pkill -CONT -x cava >/dev/null 2>&1 || true")
        hl.exec_cmd("for p in $(pgrep -f '/aurora fossilize loop' || true); do kill -CONT \"$p\" 2>/dev/null || true; done")
        hl.exec_cmd("pid=$(pgrep -x awww-daemon | head -1); [ -n \"$pid\" ] && kill -CONT \"$pid\" || true")
        hl.exec_cmd("qs ipc call bar show")
    end
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
            xwayland = { use_nearest_neighbor = false },
        })
    end)
    hl.exec_cmd("qs ipc call bar show")
    hl.exec_cmd("pkill -CONT -x cava >/dev/null 2>&1 || true")
    hl.exec_cmd("for p in $(pgrep -f '/aurora fossilize loop' || true); do kill -CONT \"$p\" 2>/dev/null || true; done")
    hl.exec_cmd("pid=$(pgrep -x awww-daemon | head -1); [ -n \"$pid\" ] && kill -CONT \"$pid\" || true")
    hl.exec_cmd((os.getenv("HOME") or "/home/dd") .. "/.nix-profile/bin/aurora shade load")
end

local function find_outputs()
    local ok, mons = pcall(function()
        return hl.get_monitors and hl.get_monitors() or {}
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

rebind("aurora_tex_expand", "window.active", function(ev)
    _G.aurora_sync_texture_expand(ev)
end)

rebind("aurora_game_close", "window.close", function()
    if not is_game_focus(hl.get_active_window()) then
        aurora_restore_desktop()
    else
        _G.aurora_sync_texture_expand()
    end
end)

_G.aurora_sync_texture_expand()

local function is_media_window(w)
    if not w then
        return false
    end
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    return cls:find("google-chrome", 1, true)
        or cls:find("chrome-", 1, true)
        or cls:find("firefox", 1, true)
        or cls:find("zen", 1, true)
        or cls == "chrome"
        or cls:find("mpv", 1, true)
        or cls:find("vlc", 1, true)
        or cls:find("celluloid", 1, true)
end

-- Dwindle оставляет YouTube «в плитке» (internal=0, client=2). Форсим covering FS.
local media_fs_busy = {}

local function promote_media_fs(w)
    w = w and (w.window or w) or nil
    if not is_media_window(w) then
        return
    end
    local addr = tostring(w.address or "")
    if addr == "" or media_fs_busy[addr] then
        return
    end
    local internal = tonumber(w.fullscreen) or 0
    local client = tonumber(w.fullscreen_client) or 0
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

rebind("aurora_media_fs", "window.fullscreen", promote_media_fs)
rebind("aurora_media_fs_active", "window.active", promote_media_fs)

rebind("aurora_monitor_pin", "monitor.added", function()
    pin_outputs()
end)

-- Снять мёртвые OW-хендлеры после прошлой конфигурации.
for _, key in ipairs({
    "aurora_ow_fs",
    "aurora_ow_fs_active",
    "aurora_vkfix_cfg",
    "aurora_game_fs",
}) do
    if _G[key] then
        pcall(function()
            _G[key]:remove()
        end)
        _G[key] = nil
    end
end
