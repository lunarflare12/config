-- Aurora Hyprland Theme

local home = os.getenv("HOME")
local activeThemePath = home .. "/.config/aurora/active-theme.lua"
local fallbackThemePath = home .. "/.config/aurora/themes/macos-golden-gate.lua"

local ok = false
local theme = nil

local activeFile = io.open(activeThemePath, "r")
if activeFile then
    activeFile:close()
    ok, theme = pcall(dofile, activeThemePath)
end

if not ok or not theme then
    ok, theme = pcall(dofile, fallbackThemePath)
end

if not ok or not theme then
    return
end

local function stripHash(color)
    if color == nil then
        return "000000"
    end
    return color:gsub("^#", "")
end

local function rgba(color, alpha)
    return "rgba(" .. stripHash(color) .. alpha .. ")"
end

local colors = theme.colors
local active = colors.borderFocus or colors.accent or colors.border
local inactive = colors.border or colors.separator

hl.config({
    general = {
        col = {
            active_border = {
                colors = {
                    rgba(active, "ff"),
                },
                angle = 0,
            },
            inactive_border = rgba(inactive, "aa"),
        },
    },
})
