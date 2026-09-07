-- SAO_Sandbox - the county's own options page may not lie either.
--
-- [C22] The operator, looking at the page [C12] built: nothing that
-- is a manual setting should be clickable before its option is
-- selected. DR-023's principle, pointed at our own dials:
-- a field you can edit that will not apply is a lie on the screen.
-- The manual number fields are dead until their switch is on.
--
-- The mechanism is vanilla's own (F-050): its Map and Multiplier rows
-- grey against their governing toggles inside the page panel's
-- prerender, every frame, reading the live checkbox - so the gating
-- reacts the moment the switch is clicked, exactly like the rows the
-- player has already seen behave this way.

SAO = SAO or {}
SAO.Sandbox = SAO.Sandbox or {}
local Sb = SAO.Sandbox

-- switch option -> the number field it governs
local GOVERNED_PAIRS = {
    ["SurvivorAwareness.PopulationGoverned"] =
        "SurvivorAwareness.Population",
    ["SurvivorAwareness.NewcomersGoverned"] =
        "SurvivorAwareness.Newcomers",
}

local function applyPairGating(panel)
    if not panel or type(panel.controls) ~= "table" then return end
    for switchName, fieldName in pairs(GOVERNED_PAIRS) do
        local switch = panel.controls[switchName]
        local field = panel.controls[fieldName]
        if switch and field then
            local on = false
            pcall(function() on = switch:isSelected(1) == true end)
            local label = panel.labels and panel.labels[fieldName]
            if on then
                pcall(function() field:setEditable(true) end)
                pcall(function() field:setEnable(true) end)
                if label then
                    pcall(function() label:setColor(1, 1, 1) end)
                end
                pcall(function()
                    field:getJavaObject():setTextColor(
                        ColorInfo.new(1, 1, 1, 1))
                end)
            else
                pcall(function() field:setEditable(false) end)
                pcall(function() field:setEnable(false) end)
                if label then
                    pcall(function() label:setColor(0.4, 0.4, 0.4) end)
                end
                pcall(function()
                    field:getJavaObject():setTextColor(
                        ColorInfo.new(0.4, 0.4, 0.4, 1))
                end)
            end
        end
    end
end

Sb.applyPairGating = applyPairGating

-- [C24] The class [C22] hung this on was never reachable: vanilla
-- declares `local SandboxOptionsScreenPanel = ...` (SandboxOptions.lua
-- line 5) - a per-file local, invisible as a global, the exact shape
-- [C3] found in the neighbour's tree. The `if` guard skipped without a
-- word, the gating never existed at runtime, and the operator typed
-- 45445 into a field whose switch was off (R-003, F-053). The SCREEN
-- class is a real global (line 3), so the county wraps its create and
-- gates its own page panel at the instance, where vanilla's per-frame
-- idiom actually runs. And a hook that cannot attach now says so
-- through the Seams: silence is how the first one died.
if SandboxOptionsScreen and SandboxOptionsScreen.create then
    local originalCreate = SandboxOptionsScreen.create
    function SandboxOptionsScreen:create()
        originalCreate(self)
        local wrapped = 0
        pcall(function()
            for _, row in ipairs(self.listbox.items) do
                local panel = row.item and row.item.panel
                if panel and type(panel.controls) == "table"
                        and panel.controls[
                            "SurvivorAwareness.PopulationGoverned"] then
                    local originalPrerender = panel.prerender
                    panel.prerender = function(p)
                        originalPrerender(p)
                        pcall(applyPairGating, p)
                    end
                    wrapped = wrapped + 1
                end
            end
        end)
        if wrapped > 0 then
            if not Sb.gatingSeen then
                Sb.gatingSeen = true
                pcall(function()
                    SAO.Log.line("SANDBOX",
                        "manual fields gated behind their switches")
                end)
            end
        else
            pcall(function()
                SAO.Seams.wentDark("sandbox-gating",
                    "no county page found on the sandbox screen")
            end)
        end
    end
else
    pcall(function()
        SAO.Seams.wentDark("sandbox-gating",
            "SandboxOptionsScreen is not reachable at load")
    end)
end

-- [C23] Overridden neighbour dials DO NOT EXIST (DR-023 as the
-- operator restated it: anything this mod overrides is deleted - an
-- overridden dial does not need to exist in sandbox settings at
-- all). Deletion happens at the list the screen builds its
-- panels from - ServerSettingsScreen.getSandboxSettingsTable - so
-- the rows are never constructed: no grey ghosts, no layout holes.
-- The enforcement stays in the absorb module's GetOption seam either
-- way; this is the screen telling the truth.
local REMOVED_SETTINGS = {
    ["KnoxSurvivors.MaxPersistentSurvivors"] = true,
    ["KnoxSurvivors.MaxNearbySurvivors"] = true,
}

if ServerSettingsScreen and ServerSettingsScreen.getSandboxSettingsTable then
    local originalTable = ServerSettingsScreen.getSandboxSettingsTable
    ServerSettingsScreen.getSandboxSettingsTable = function(...)
        local pages = originalTable(...)
        local removed = 0
        pcall(function()
            for _, page in ipairs(pages or {}) do
                local settings = page.settings
                if type(settings) == "table" then
                    for index = #settings, 1, -1 do
                        local entry = settings[index]
                        if type(entry) == "table"
                            and REMOVED_SETTINGS[entry.name] then
                            table.remove(settings, index)
                            removed = removed + 1
                        end
                    end
                end
            end
        end)
        if removed > 0 and not Sb.removalSeen then
            Sb.removalSeen = true
            pcall(function()
                SAO.Log.line("SANDBOX", removed
                    .. " overridden neighbour dial(s) removed from the "
                    .. "options screen")
            end)
        end
        return pages
    end
end

return Sb
