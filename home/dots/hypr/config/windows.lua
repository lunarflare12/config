local GAME_MONITOR = "DP-1"
-- Local 4 on the ultrawide (DP-1 owns 1-10, HDMI owns 11-20).
local GAME_WORKSPACE = 4
-- Native Dota 2 is class dota2, not steam_app_570.
local GAME_CLASS = "^(steam_app_|dota2|[Mm]inecraft)"
-- Nix wraps the binary as .gamescope-wrapped; class match is whole-string.
local GAMESCOPE_CLASS = ".*gamescope.*"
local ALL_GAME_CLASS = "^(steam_app_|dota2|.*gamescope.*|[Mm]inecraft)"

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
    -- Same chrome as Chrome/Telegram: tiled, default border. no_max_size so
    -- ICCCM max size cannot freeze the CEF buffer smaller than the tile.
    { name = "steam-cef", match = { class = "^(steam)$" }, opaque = true, no_blur = true, render_unfocused = true, no_max_size = true, tile = true },
    -- Empty-title CEF helper: hover menus. If Hyprland tiles it, the library
    -- jumps and a "new window" appears. stay_focused+min_size is Valve/Hypr wiki.
    { name = "steam-menus", match = { class = "^(steam)$", title = "^$" }, float = true, stay_focused = true, no_initial_focus = true, no_follow_mouse = true, min_size = { 1, 1 }, no_anim = true, border_size = 0, rounding = 0, decorate = false, opaque = true, no_blur = true },
    { name = "steam-dialogs", match = { class = "^(steam)$", title = "negative:^(Steam|Sign in to Steam)$" }, float = true, no_anim = true, no_initial_focus = true, border_size = 0 },
    { name = "steam-login", match = { class = "^(steam)$", title = "^(Sign in to Steam)$" }, float = true, center = true, size = "780 520" },
    { name = "steam-x11", match = { class = "^$", title = "^(Steam.*)$", xwayland = true }, opaque = true, no_blur = true, float = true, center = true },
    { name = "float-media", match = { title = "^(imv|mpv|danmufloat|termfloat|nemo|ncmpcpp)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-waydroid", match = { class = "^(Waydroid)$" }, float = true, size = "1280 720", center = true },
    { name = "float-insta360", match = { class = "^(insta360linkgui)$" }, float = true, size = "1760 1000", center = true },
    { name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol-qt)$" }, float = true },
    { name = "float-satty", match = { class = "^(com.gabm.satty|satty)$" }, float = true, monitor = "DP-1", center = true, no_anim = true },
    { name = "float-picture-in-picture", match = { class = "^()$", title = "^(Picture in picture)$" }, float = true },
    { name = "float-save-file", match = { class = "^()$", title = "^(Save File)$" }, float = true },
    { name = "float-open-file", match = { class = "^()$", title = "^(Open File)$" }, float = true },
    { name = "float-zen-pip", match = { class = "^(ZenBrowser)$", title = "^(Picture-in-Picture)$" }, float = true },
    { name = "float-blueman", match = { class = "^(blueman-manager)$" }, float = true },
    { name = "float-bitwarden", match = { class = "^(chrome-nngceckbapebfimnlniiiahkandclblb-Default)$" }, float = true },
    { name = "float-xdg-portal", match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$" }, float = true },
    { name = "float-termfloat", match = { class = "^(termfloat)$" }, float = true, center = true, size = "520 220" },
    { name = "float-zenity", match = { class = "^(zenity)$" }, float = true },
    { name = "float-steam-updater", match = { class = "^()$", title = "^(Steam - Self Updater)$" }, float = true },
    { name = "float-dell-controller", match = { class = "^(python3)$", title = "^(Dell G Series Controller)$" }, float = true },
    { name = "finder-menus", match = { class = "^(thunar|Thunar)$", title = "^$" }, float = true, rounding = 14, border_size = 0, no_anim = true, decorate = false, no_initial_focus = true },
    { name = "finder-main", match = { class = "^(thunar|Thunar)$", title = ".+" }, float = true, rounding = 20, border_size = 0, size = "1180 740" },
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

-- Overwatch: compositor maximize, client stays windowed 1920. Client FS (2)
-- makes DXGI match the 2560 output and Use219=0 pillarboxes. no_max_size
-- stops ICCCM max=1920 from shrinking the Hyprland window.
local OW_CLASS = "^(steam_app_2357570|[Oo]verwatch)"
game_rule("overwatch-class", { class = OW_CLASS }, {
    confine_pointer = true,
    fullscreen_state = "1 0",
    no_max_size = true,
    -- Keep the compositor window at 2560. The game still renders 1920;
    -- csgo-vulkan-fix stretches that buffer. Without this, Wine parks the
    -- 1920 window on the right of the ultrawide (black bar on the left).
    suppress_event = "x11configurerequest",
})
game_rule("overwatch-initial-class", { initial_class = OW_CLASS }, {
    confine_pointer = true,
    fullscreen_state = "1 0",
    no_max_size = true,
    suppress_event = "x11configurerequest",
})

local function setup_vkfix()
    if not (hl.plugin and hl.plugin.csgo_vulkan_fix and hl.plugin.csgo_vulkan_fix.vkfix_app) then
        return
    end
    hl.config({
        plugin = {
            csgo_vulkan_fix = { fix_mouse = false },
        },
    })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "steam_app_2357570", w = 1920, h = 1080 })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "overwatch.exe", w = 1920, h = 1080 })
    hl.plugin.csgo_vulkan_fix.vkfix_app({ app = "Overwatch", w = 1920, h = 1080 })
end
setup_vkfix()

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

local function pin_game(w, client_fs)
    pcall(function()
        hl.dispatch(hl.dsp.window.move({ workspace = GAME_WORKSPACE, window = w }))
    end)
    pcall(function()
        hl.dispatch(hl.dsp.focus({ workspace = GAME_WORKSPACE }))
    end)
    pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, internal = 1, client = client_fs }))
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
    local title = tostring(w.title or w.initial_title or "")
    if title ~= "" and title ~= " " then
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
    if cls:find("steam_app_2357570", 1, true) or cls:find("overwatch", 1, true) or title:find("overwatch", 1, true) then
        pin_game(w, 0)
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
if _G.aurora_game_fs then
    pcall(function()
        _G.aurora_game_fs:remove()
    end)
    _G.aurora_game_fs = nil
end

local function needs_texture_expand(w)
    if not w then
        return false
    end
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    local title = string.lower(tostring(w.title or w.initial_title or ""))
    return cls:find("steam_app_2357570", 1, true) or cls:find("overwatch", 1, true) or title:find("overwatch", 1, true)
end

_G.aurora_sync_texture_expand = function(win)
    local w = win and (win.window or win) or hl.get_active_window()
    local on = needs_texture_expand(w)
    pcall(function()
        hl.config({ render = { expand_undersized_textures = on } })
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
_G.aurora_sync_texture_expand()
