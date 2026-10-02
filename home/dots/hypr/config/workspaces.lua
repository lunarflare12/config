local WS_PER = 12

-- Physical panels in left→right order. NVIDIA renames connectors across
-- boots, so resolve the live output by name or model description and bind
-- each workspace bank only to that name (never to a missing alias).
local PANELS = {
    {
        aliases = { "DP-1", "DP-4" },
        hints = { "Mi 30", "Xiaomi" },
    },
    {
        aliases = { "HDMI-A-1", "HDMI-A-2" },
        hints = { "PHL", "Philips" },
    },
}

local function monitors()
    local ok, mons = pcall(function()
        if hl.get_monitors then
            return hl.get_monitors()
        end
        return {}
    end)
    if not ok or type(mons) ~= "table" then
        return {}
    end
    return mons
end

local function match_panel(panel, mon)
    local n = tostring(mon.name or mon.output or "")
    local d = tostring(mon.description or mon.desc or mon.model or "")
    for _, alias in ipairs(panel.aliases) do
        if n == alias then
            return true
        end
    end
    for _, hint in ipairs(panel.hints) do
        if d:find(hint, 1, true) then
            return true
        end
    end
    return false
end

local function resolve_name(panel)
    for _, mon in ipairs(monitors()) do
        if match_panel(panel, mon) then
            local n = tostring(mon.name or mon.output or "")
            if n ~= "" then
                return n
            end
        end
    end
    -- Boot order can race monitor enumeration; fall back to the preferred alias.
    return panel.aliases[1]
end

local function apply_workspace_rules()
    for i, panel in ipairs(PANELS) do
        local name = resolve_name(panel)
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
end

apply_workspace_rules()
hl.on("monitor.added", apply_workspace_rules)
hl.on("config.reloaded", apply_workspace_rules)
