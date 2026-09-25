local WS_PER = 12
local MONITORS = { "DP-1", "HDMI-A-1" }

for i, name in ipairs(MONITORS) do
    local base = (i - 1) * WS_PER
    for n = 1, WS_PER do
        hl.workspace_rule({
            workspace = tostring(base + n),
            monitor = name,
            persistent = true,
            default = n == 1,
        })
    end
end
