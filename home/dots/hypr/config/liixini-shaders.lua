-- liixini/shaders via HyprWindowShade: one-shot open/close GLSL on desktop windows.
-- Never attach to games / Steam — that path costs FPS and remaps the cursor.
local home = os.getenv("HOME") or "/home/dd"
local cfg = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/hypr"
local shader_root = cfg .. "/shaders/liixini"
local current_file = shader_root .. "/CURRENT"
local script = home .. "/.config/scripts/hypr-window-shade.sh"

local function read_trim(path)
    local f = io.open(path, "r")
    if not f then
        return nil
    end
    local s = f:read("*a") or ""
    f:close()
    return (s:gsub("%s+", ""))
end

local function effect_name()
    return read_trim(current_file) or "crosshatch"
end

-- Positive-only desktop classes. negative: on tag rules still tagged OW
-- and remapped the cursor (clicks miss by the bar/frame offset).
-- Class match is case-sensitive. Telegram appends a hash suffix.
local DESKTOP = "^(kitty|com\\.mitchellh\\.ghostty|ghostty|Alacritty|org\\.wezfurlong\\.wezterm|[Tt]hunar|org\\.gnome\\.Nautilus|Cursor|cursor|code|Code|google-chrome|chrome|chrome-dd|chrome-az|chrome-hika|chrome-sciencesoft|firefox|zen|vesktop|discord|org\\.telegram\\.desktop.*|[Ss]potify|obsidian|steam_app_761890)$"

local function apply_rules()
    local name = effect_name()
    local open = shader_root .. "/" .. name .. "/open.glsl"
    local close = shader_root .. "/" .. name .. "/close.glsl"
    hl.window_rule({
        name = "liixini-shader-open",
        match = { class = DESKTOP },
        tag = "+shader_open:" .. open,
    })
    hl.window_rule({
        name = "liixini-shader-close",
        match = { class = DESKTOP },
        tag = "+shader_close:" .. close,
    })
    -- Belt-and-suspenders: never keep shade tags on Overwatch.
    hl.window_rule({
        name = "liixini-strip-ow-open",
        match = { class = "^steam_app_2357570$" },
        tag = "-shader_open:" .. open,
    })
    hl.window_rule({
        name = "liixini-strip-ow-close",
        match = { class = "^steam_app_2357570$" },
        tag = "-shader_close:" .. close,
    })
end

local function load_plugin()
    hl.exec_cmd(script .. " load")
end

apply_rules()
hl.on("hyprland.start", load_plugin)
hl.on("config.reloaded", function()
    apply_rules()
    load_plugin()
end)
