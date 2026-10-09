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
require "SAO_SourceSandboxPages"
require "SAO_WeekOneSandboxPages"
local SOURCE_PAGES = {}
for id, rule in pairs(SAO.SourceSandboxPages.options) do
    SOURCE_PAGES[id] = rule
end
for id, rule in pairs(SAO.WeekOneSandboxPages.options) do
    SOURCE_PAGES[id] = rule
end

-- Source packages and their installed originals can register the same saved
-- option ID. The native options list retains both entries while name lookup
-- selects the last one. Keep the control on that selected option's page in
-- both settings screens; leave the original source registration intact.
local function coalesceSourcePages(pages)
    local options = getSandboxOptions and getSandboxOptions()
    if not options or type(pages) ~= "table" then return pages, 0 end
    local occurrences = {}
    for pageIndex, page in ipairs(pages) do
        for settingIndex, setting in ipairs(page.settings or {}) do
            local rule = SOURCE_PAGES[setting.name]
            if rule then
                local original = getText("Sandbox_" .. rule.originalPage)
                local owned = getText("Sandbox_" .. rule.ownedPage)
                local pageId = page.name == original and rule.originalPage
                    or page.name == owned and rule.ownedPage or nil
                if rule.preferOwned and pageId == rule.ownedPage then
                    local suffix = setting.name:match("^BanditsWeekOne%.(.+)$")
                    if suffix then
                        local textKey = "Sandbox_SAO_WeekOne_Control_" .. suffix
                        setting.translatedName = getText(textKey)
                        if rule.hasTooltip then
                            setting.tooltip = getText(textKey .. "_tooltip")
                        end
                        if suffix == "StartTime" then
                            setting.values = {}
                            for value = 1, 6 do
                                setting.values[value] = getText(textKey
                                    .. "_option" .. value)
                            end
                        end
                    end
                end
                local rows = occurrences[setting.name] or {}
                rows[#rows + 1] = {pageIndex = pageIndex,
                    settingIndex = settingIndex, pageId = pageId}
                occurrences[setting.name] = rows
            end
        end
    end
    local remove = {}
    for id, rows in pairs(occurrences) do
        if #rows > 1 then
            local rule = SOURCE_PAGES[id]
            local option = options:getOptionByName(id)
            local selected = option and option:getPageName()
            if (selected == rule.originalPage or selected == rule.ownedPage)
                    and rule.originalPage ~= rule.ownedPage then
                local keep
                local complete = true
                for _, row in ipairs(rows) do
                    if not row.pageId then complete = false end
                    if row.pageId == selected then keep = row end
                end
                if rule.preferOwned then
                    for _, row in ipairs(rows) do
                        if row.pageId == rule.ownedPage then keep = row end
                    end
                end
                if complete and keep then
                    for _, row in ipairs(rows) do
                        if row ~= keep then
                            remove[row.pageIndex] = remove[row.pageIndex] or {}
                            remove[row.pageIndex][row.settingIndex] = true
                        end
                    end
                end
            end
        end
    end
    local result, removed = {}, 0
    for index, page in ipairs(pages) do
        local drop = remove[index]
        if not drop then
            result[index] = page
        else
            local replacement = {}
            for key, value in pairs(page) do replacement[key] = value end
            replacement.settings = {}
            for settingIndex, setting in ipairs(page.settings) do
                if drop[settingIndex] then removed = removed + 1
                else replacement.settings[#replacement.settings + 1] = setting end
            end
            result[index] = #replacement.settings > 0 and replacement or false
        end
    end
    return result, removed
end

Sb.coalesceSourcePages = coalesceSourcePages

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

local CREATOR_STRIKE_CONTROLS = {
    "BanditsWeekOne.EventFinalSolution",
    "SurvivorAwareness.WeekOneNuke",
}

local function applyCreatorStrikeGating(panel)
    if not (MainScreen and MainScreen.instance
        and MainScreen.instance.createWorld == true)
        or not panel or type(panel.controls) ~= "table" then return end
    local explanation = getText("Sandbox_SAO_WeekOne_CreatorChoice")
    for _, id in ipairs(CREATOR_STRIKE_CONTROLS) do
        local control = panel.controls[id]
        if control then
            if control.isTickBox and control.disableOption then
                -- Native ISTickBox checks `enable` for the mouse and its
                -- disabled option map for the joypad forceClick path.
                control.enable = false
                control:disableOption("", true)
            else
                pcall(function()
                    SAO.Seams.wentDark("creator-strike-sandbox-control",
                        "strike option is not a native tick box")
                end)
            end
            control.tooltip = explanation
            local label = panel.labels and panel.labels[id]
            if label then
                label.tooltip = explanation
                pcall(function() label:setColor(0.4, 0.4, 0.4) end)
            end
        end
    end
end

Sb.applyCreatorStrikeGating = applyCreatorStrikeGating

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
                        and (panel.controls[
                            "SurvivorAwareness.PopulationGoverned"]
                            or panel.controls[
                                "SurvivorAwareness.WeekOneNuke"]
                            or panel.controls[
                                "BanditsWeekOne.EventFinalSolution"]) then
                    local originalPrerender = panel.prerender
                    panel.prerender = function(p)
                        originalPrerender(p)
                        pcall(applyPairGating, p)
                        pcall(applyCreatorStrikeGating, p)
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
        local selected, sourceRemoved = coalesceSourcePages(pages)
        if sourceRemoved == 0 then return pages end
        local visible = {}
        for _, page in ipairs(selected) do
            if page then visible[#visible + 1] = page end
        end
        return visible
    end
end

-- The server editor builds from a private SettingsTable instead of calling
-- getSandboxSettingsTable(). Rebuild only affected panels after its native
-- create step, then rebind the existing controls map to the visible widget.
if ServerSettingsScreen and ServerSettingsScreen.create then
    local originalServerCreate = ServerSettingsScreen.create
    function ServerSettingsScreen:create()
        originalServerCreate(self)
        local editor = self.pageEdit
        local listbox = editor and editor.listbox
        if not listbox or type(listbox.items) ~= "table" then return end
        local category, entries, pages = nil, {}, {}
        for index, item in ipairs(listbox.items) do
            if item.item and item.item.category then
                category = item.item.category
            elseif category and category.name == "Sandbox"
                    and item.item and item.item.page then
                entries[#entries + 1] = {index = index, item = item.item,
                    category = category}
                pages[#pages + 1] = item.item.page
            end
        end
        local selected, removed = coalesceSourcePages(pages)
        if removed == 0 then return end
        for index = #entries, 1, -1 do
            local entry, page = entries[index], selected[index]
            if not page then
                listbox:removeItemByIndex(entry.index)
            elseif page ~= pages[index] then
                entry.item.page = page
                entry.item.panel = editor:createPanel(entry.category, page)
            end
        end
        local controls = editor.controls and editor.controls.Sandbox
        if controls then
            for index, entry in ipairs(entries) do
                local page = selected[index]
                local panel = entry.item.panel
                if page and panel and panel.controls then
                    for _, setting in ipairs(page.settings) do
                        if SOURCE_PAGES[setting.name] then
                            controls[setting.name] = panel.controls[setting.name]
                        end
                    end
                end
            end
        end
    end
end

return Sb
