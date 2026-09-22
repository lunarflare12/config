local GAME_MONITOR = "DP-1"
-- Local 4 on the ultrawide (DP-1 owns 1-10, HDMI owns 11-20).
local GAME_WORKSPACE = 4
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
    { name = "opaque-discord", match = { class = "^([Dd]iscord)$" }, opaque = true, no_blur = true, render_unfocused = true },
    -- HTML5 `f` is client FS (2) while dwindle's layout-aware handler keeps
    -- internal=0 (player stays in the bar/dock tile). sync + immediate + no
    -- ICCCM max size so the lua promoter can set internal=2 covering the output.
    { name = "browser-sync-fs", match = { class = "^(google-chrome|chrome|firefox|zen|mpv|vlc|celluloid)$" }, sync_fullscreen = true, no_anim = true, no_max_size = true, immediate = true, idle_inhibit = "fullscreen" },
    { name = "opaque-cursor", match = { class = "^(cursor)$" }, opaque = true, no_blur = true, render_unfocused = true },
    { name = "opaque-code", match = { class = "^(code|Code)$" }, opaque = true, no_blur = true, render_unfocused = true },
    { name = "opaque-obsidian", match = { class = "^(obsidian)$" }, opaque = true, no_blur = true, render_unfocused = true },
    -- Steam CEF at 1x. Do not render_unfocused: GameMode's 205 FPS cap
    -- then composites Steam on the CPU. Plugin must not match class steam
    -- or Hyprland stretches the 16:9 buffer across 2560 and clicks miss.
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
    { name = "float-satty", match = { class = "^(com.gabm.satty|satty)$" }, float = true, center = true, no_anim = true, no_max_size = true },
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
        monitor = GAME_MONITOR,
        workspace = GAME_WORKSPACE,
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

-- Overwatch: compositor exclusive (covers gaps_out), client stays windowed
-- 2560x1440. Client FS (2) makes DXGI match the 2560x1080 output and
-- Use219=0 pillarboxes. Maximize (1) leaves the 10px right/bottom gap.
-- no_max_size stops ICCCM max from shrinking the Hyprland window.
local OW_CLASS = "^(steam_app_2357570|[Oo]verwatch\\.exe|[Oo]verwatch)$"
game_rule("overwatch-class", { class = OW_CLASS }, {
    confine_pointer = true,
    fullscreen_state = "2 0",
    no_max_size = true,
    -- Wine/Battle.net spam activate; do not yank the current workspace.
    focus_on_activate = false,
    -- Keep the compositor window at 2560x1080. The game still renders
    -- 2560x1440; csgo-vulkan-fix stretches that buffer. Without this,
    -- Wine parks the taller window and leaves a black bar.
    suppress_event = "x11configurerequest",
})
game_rule("overwatch-initial-class", { initial_class = OW_CLASS }, {
    confine_pointer = true,
    fullscreen_state = "2 0",
    no_max_size = true,
    focus_on_activate = false,
    suppress_event = "x11configurerequest",
})

-- Plugin is compositor-global. Never register from aurora-game alone:
-- Albion/Dota set that flag and the store matcher stretches Steam.

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

-- Real Overwatch client only. Steam's store/library title is often
-- "Overwatch 2" — matching that yanked every desktop onto workspace 4.
local function is_overwatch(w)
    local cls = window_class(w)
    if cls:find("steam_app_2357570", 1, true) then
        return true
    end
    if cls:find("steam", 1, true) and not cls:find("steam_app_", 1, true) then
        return false
    end
    return cls:find("overwatch", 1, true)
end

local function same_game_count(w)
    local n = 0
    local want_ow = is_overwatch(w)
    local cls = window_class(w)
    local ok, wins = pcall(function()
        return hl.get_windows()
    end)
    if not ok or type(wins) ~= "table" then
        return 1
    end
    for _, x in ipairs(wins) do
        if want_ow then
            if is_overwatch(x) then
                n = n + 1
            end
        elseif window_class(x) == cls or (cls ~= "" and window_class(x):find(cls, 1, true)) then
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
        hl.exec_cmd("/home/dd/.config/scripts/gamemode-start.sh")
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
    -- Nested gamescope first: title is "Overwatch" but client FS must stay 2.
    -- Do not listen to window.fullscreen — re-dispatching there fights 1 2 vs 1 0.
    if cls:find("gamescope", 1, true) then
        pin_game(w, 2)
        return
    end
    if is_overwatch(w) then
        pin_game(w, 0, 2)
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
    if is_overwatch(w) then
        return true
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

_G.aurora_sync_texture_expand = function(win)
    local w = win and (win.window or win) or hl.get_active_window()
    local ingame = is_game_focus(w)
    pcall(function()
        hl.config({
            render = {
                -- Stretch is the vkfix plugin + ow-stretch-plugin.sh.
                -- Turning this on without fix_mouse makes OW clicks drift left.
                expand_undersized_textures = false,
                send_content_type = ingame,
            },
            misc = {
                mouse_move_focuses_monitor = true,
                render_unfocused_fps = ingame and 205 or 15,
            },
            debug = {
                render_solitary_wo_damage = ingame,
            },
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
    pcall(function()
        hl.exec_cmd((os.getenv("HOME") or "/home/dd") .. "/.config/scripts/ow-stretch-plugin.sh sync")
    end)
end)
_G.aurora_sync_texture_expand()
pcall(function()
    hl.exec_cmd((os.getenv("HOME") or "/home/dd") .. "/.config/scripts/ow-stretch-plugin.sh sync")
end)

local function is_media_window(w)
    if not w then
        return false
    end
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    return cls:find("google-chrome", 1, true)
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

-- OW must stay compositor-fullscreen / client-windowed. Exclusive client
-- FS (2) makes DXGI match 2560x1080 and the 1440 buffer + mouse remap drift.
local ow_fs_busy = false
local function pin_ow_windowed(win)
    local w = win and (win.window or win) or nil
    if not is_overwatch(w) or ow_fs_busy then
        return
    end
    local internal = tonumber(w.fullscreen) or 0
    local client = tonumber(w.fullscreen_client) or 0
    if internal == 2 and client == 0 then
        return
    end
    ow_fs_busy = true
    pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state({
            window = w,
            internal = 2,
            client = 0,
        }))
    end)
    ow_fs_busy = false
end
if _G.aurora_ow_fs then
    pcall(function()
        _G.aurora_ow_fs:remove()
    end)
end
_G.aurora_ow_fs = hl.on("window.fullscreen", pin_ow_windowed)
