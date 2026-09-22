local home = os.getenv("HOME")
local theme = "macOS"
local size = "24"

local tf = io.open(home .. "/.cache/aurora/current-cursor-theme", "r")
if tf then
    local line = tf:read("*l")
    tf:close()
    if line and line:match("%S") then
        theme = line:gsub("%s+", "")
    end
end

local sf = io.open(home .. "/.cache/aurora/current-cursor-size", "r")
if sf then
    local line = sf:read("*l")
    sf:close()
    if line and line:match("%S") then
        size = line:gsub("%s+", "")
    end
end

hl.env("XCURSOR_THEME", theme)
hl.env("XCURSOR_SIZE", size)
hl.env("HYPRCURSOR_THEME", theme)
hl.env("HYPRCURSOR_SIZE", size)
