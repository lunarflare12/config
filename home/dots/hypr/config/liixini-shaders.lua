-- liixini: одноразовые open/close GLSL на десктопных окнах (HyprWindowShade).
-- На игры/Steam не вешаем — FPS и курсор.
local home = os.getenv("HOME") or "/home/dd"
local cfg = (os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")) .. "/hypr"
local shader_root = cfg .. "/shaders/liixini"
local current_file = shader_root .. "/CURRENT"
local script = home .. "/.nix-profile/bin/aurora shade"

local function effect_name()
    local f = io.open(current_file, "r")
    if not f then
        return "crosshatch"
    end
    local s = f:read("*a") or ""
    f:close()
    return (s:gsub("%s+", "")) ~= "" and (s:gsub("%s+", "")) or "crosshatch"
end

-- Только десктоп. Match чувствителен к регистру; у Telegram есть hash-суффикс.
local DESKTOP =
    "^(kitty|com\\.mitchellh\\.ghostty|ghostty|Alacritty|org\\.wezfurlong\\.wezterm|[Tt]hunar|org\\.gnome\\.Nautilus|Cursor|cursor|code|Code|google-chrome|chrome|chrome-dd|chrome-az|chrome-hika|chrome-sciencesoft|firefox|zen|vesktop|discord|org\\.telegram\\.desktop.*|[Ss]potify|obsidian|steam_app_761890)$"

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
