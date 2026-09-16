local GAME_MONITOR = "DP-1"
-- Local 4 on the ultrawide (HDMI owns 1-10, DP-1 owns 11-20).
local GAME_WORKSPACE = "14"
local GAME_CLASS = "^(steam_app_|[Mm]inecraft)"
-- Nix wraps the binary as .gamescope-wrapped; class match is whole-string.
local GAMESCOPE_CLASS = ".*gamescope.*"
local ALL_GAME_CLASS = "^(steam_app_|.*gamescope.*|[Mm]inecraft)"

hl.window_rule({
    name = "suppress-maximize",
    match = { class = "negative:" .. ALL_GAME_CLASS },
    suppress_event = "maximize",
})
hl.window_rule({ name = "fix-xwayland-drags", match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })

for _, rule in ipairs({
    { name = "float-pip", match = { title = "^(Picture-in-Picture)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-media", match = { title = "^(imv|mpv|danmufloat|termfloat|nemo|ncmpcpp)$" }, float = true, size = "960 540", move = "25%- 0" },
    { name = "float-waydroid", match = { class = "^(Waydroid)$" }, float = true, size = "1280 720", center = true },
    { name = "float-pavucontrol", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol-qt)$" }, float = true },
    { name = "float-satty", match = { class = "^(com.gabm.satty|satty)$" }, float = true, pin = true, no_anim = true },
    { name = "float-picture-in-picture", match = { class = "^()$", title = "^(Picture in picture)$" }, float = true },
    { name = "float-save-file", match = { class = "^()$", title = "^(Save File)$" }, float = true },
    { name = "float-open-file", match = { class = "^()$", title = "^(Open File)$" }, float = true },
    { name = "float-zen-pip", match = { class = "^(ZenBrowser)$", title = "^(Picture-in-Picture)$" }, float = true },
    { name = "float-blueman", match = { class = "^(blueman-manager)$" }, float = true },
    { name = "float-bitwarden", match = { class = "^(chrome-nngceckbapebfimnlniiiahkandclblb-Default)$" }, float = true },
    { name = "float-xdg-portal", match = { class = "^(xdg-desktop-portal-gtk|xdg-desktop-portal-kde|xdg-desktop-portal-hyprland)(.*)$" }, float = true },
    { name = "float-polkit", match = { class = "^(polkit-gnome-authentication-agent-1|hyprpolkitagent|org.org.kde.polkit-kde-authentication-agent-1)(.*)$" }, float = true },
    { name = "float-zenity", match = { class = "^(zenity)$" }, float = true },
    { name = "float-steam-updater", match = { class = "^()$", title = "^(Steam - Self Updater)$" }, float = true },
    { name = "float-dell-controller", match = { class = "^(python3)$", title = "^(Dell G Series Controller)$" }, float = true },
    { name = "float-thunar-rename", match = { class = "^(thunar)$", title = "^(Rename.*)$" }, float = true, size = "500 200" },
    { name = "float-thunar-progress", match = { class = "^(thunar)$", title = "^(File Operation Progress)$" }, float = true },
    { name = "float-thunar-confirm", match = { class = "^(thunar)$", title = "^(Confirm.*)$" }, float = true },
    { name = "float-thunar-question", match = { class = "^(thunar)$", title = "^(Question)$" }, float = true },
    { name = "float-thunar-create", match = { class = "^(thunar)$", title = "^(Create.*)$" }, float = true },
    { name = "float-thunar-properties", match = { class = "^(thunar)$", title = "^(Properties)$" }, float = true, size = "600 500" },
    { name = "center-thunar-dialogs", match = { class = "^(thunar)$", title = "^(Rename.*|File Operation Progress|Confirm.*|Question|Create.*|Properties)$" }, center = true },
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
        workspace = 14,
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
        hl.dispatch(hl.dsp.window.move({ workspace = 14, window = w }))
    end)
    pcall(function()
        hl.dispatch(hl.dsp.focus({ workspace = 14 }))
    end)
    pcall(function()
        hl.dispatch(hl.dsp.window.fullscreen_state({ window = w, internal = 1, client = client_fs }))
    end)
end

local function game_to_desk(win)
    if not win then
        return
    end
    local w = win.window or win
    local cls = string.lower(tostring(w.initial_class or "") .. " " .. tostring(w.class or ""))
    local title = string.lower(tostring(w.title or ""))
    -- Nested gamescope first: client FS must stay 2.
    -- Do not listen to window.fullscreen — re-dispatching there fights 1 2 vs 1 0.
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
    if cls:find("steam_app_", 1, true) or cls:find("minecraft", 1, true) then
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
