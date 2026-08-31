-- Border 66's driver. Pretends N profession mods are registered and
-- asks the real `Census.catalog` what share of the county they end up
-- claiming.
--
-- The bridge is the only stub - `listProfessions` is the one thing
-- here that needs a running game, and it returns a flat
-- `namespace:Path|namespace:Path` string. Everything downstream of it
-- (classification into buckets, the scale to MOD_SHARE, the floor of
-- one) is the real module.

SAO = SAO or {}

-- `namespace:Path` per entry, exactly as the bridge returns them.
local function fabricate(n)
    local parts = {}
    for i = 1, n do
        parts[#parts + 1] = "modx:Fabricated" .. i
    end
    return table.concat(parts, "|")
end

-- Returns "<modWeight> <baseWeight> <total>" for a county with `n`
-- profession mods installed.
function PROBE_MODSHARE(n)
    local listed = fabricate(n)
    SAOJavaBridge = {
        listProfessions = function() return listed end,
    }
    local cat = SAO.Census.catalog()
    local mod, base = 0, 0
    for _, row in ipairs(cat.rows) do
        if row.classified then
            mod = mod + (row.per10k or 0)
        else
            base = base + (row.per10k or 0)
        end
    end
    return mod .. " " .. base .. " " .. cat.total
end
