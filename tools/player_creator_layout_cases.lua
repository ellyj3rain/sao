-- Focused layout and input observations around the production SAO creator UI.
-- player_creator_cases.lua supplies synthetic ISUI ports; native API pins live
-- in player_creator_layout_test.py. This does not render game pixels.
local passed, failed = 0, 0
local failures = {}
local function check(name, value)
    if value then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        failures[#failures + 1] = name
        print("FAIL " .. name)
    end
end

local fontWidths = {Small = 7, Medium = 9, Large = 12}
getTextManager = function()
    return {MeasureStringX = function(_, font, value)
        return #tostring(value) * (fontWidths[font] or 7)
    end}
end
function ISPanelJoypad:drawRect(x, y, width, height)
    self.rects = self.rects or {}
    self.rects[#self.rects + 1] = {x = x, y = y,
        width = width, height = height}
end
function ISPanelJoypad:drawText(value, x, y, r, g, b, a, font)
    self.drawn = self.drawn or {}
    self.drawn[#self.drawn + 1] = {text = value, x = x, y = y,
        width = getTextManager():MeasureStringX(font, value), font = font}
end

local context = {
    world = "Long preserved save name chosen in the native game",
    gameMode = "Sandbox", newWorld = true,
    forename = "Avery", surname = "Stone",
    nativeDescriptorId = 6, playerSlot = 0, accountKey = "player:One",
    scenario = "A very long Where I Was scenario selection",
    origin = "This Is Your Life origin selected earlier",
    weekOneVariant = "Week One scenario chosen earlier",
    originalBwoNuke = true,
}
local confirmCalls, continueCalls = 0, 0
SAO.Creator = {
    newDraft = function()
        local ctx = {}
        for key, value in pairs(context) do ctx[key] = value end
        return {context = ctx, groupName = "", background = "",
            nukeChoice = ctx.newWorld and "none" or nil}
    end,
    confirm = function(draft)
        confirmCalls = confirmCalls + 1
        if draft.background == "" then return false, "background-required" end
        return true
    end,
    continueConfirmed = function(_, continuation)
        continueCalls = continueCalls + 1
        continuation()
        return true
    end,
}

local function containsDraw(panel, prefix)
    for _, row in ipairs(panel.drawn or {}) do
        if row.text:sub(1, #prefix) == prefix then return true end
    end
    return false
end

local function controlsFit(panel)
    local fields = {panel.groupEntry, panel.backgroundEntry,
        panel.backButton, panel.continueButton}
    if panel.noneButton then
        fields[#fields + 1] = panel.noneButton
        fields[#fields + 1] = panel.saoButton
    end
    for _, field in ipairs(fields) do
        if field.x < 0 or field.y < 0 or field.width < 1
            or field.height < 1
            or field.x + field.width > panel.width
            or field.y + field.height > panel.height then return false end
    end
    if panel.groupEntry.y + panel.groupEntry.height
        >= panel.backgroundEntry.y - 16 then return false end
    if panel.backgroundEntry.y + panel.backgroundEntry.height
        >= panel.continueButton.y - 10 then return false end
    if panel.noneButton then
        if panel.noneButton.x + panel.noneButton.width
            > panel.saoButton.x - 8 then return false end
        if panel.noneButton.y + panel.noneButton.height
            >= panel.continueButton.y - 10 then return false end
        if not panel.compact and panel.backgroundEntry.y
            + panel.backgroundEntry.height
            >= panel.noneButton.y - 15 then return false end
    end
    return true
end

local function textFits(panel)
    for _, row in ipairs(panel.drawn or {}) do
        if row.x < 0 or row.y < 0
            or row.x + row.width > panel.width - 2
            or row.y > panel.height - 20 then return false end
    end
    return true
end

local function completeUtf16(value)
    local i = 1
    while i <= #value do
        local unit = value:byte(i)
        if unit >= 0xD800 and unit <= 0xDBFF then
            if i == #value then return false end
            local trailing = value:byte(i + 1)
            if trailing < 0xDC00 or trailing > 0xDFFF then
                return false
            end
            i = i + 2
        elseif unit >= 0xDC00 and unit <= 0xDFFF then
            return false
        else
            i = i + 1
        end
    end
    return true
end

function fixtureCreatorLayout()
    local UI = SAO.Creator.UI
    local core = getCore()
    local source = {visible = true,
        setVisible = function(self, value) self.visible = value end}
    local profiles = {
        {1280, 736, "desktop-720", false},
        {800, 516, "desktop-500", false},
        {800, 356, "short-wide-340", true},
        {716, 356, "minimum-wide-340", true},
        {380, 420, "narrow-404", true},
        {640, 480, "narrow-464", true},
    }
    for _, profile in ipairs(profiles) do
        core.width, core.height = profile[1], profile[2]
        context.newWorld = true
        local shown = UI.show(source, function() end)
        local panel = UI.active
        panel:prerender()
        check("geometry/" .. profile[3], shown == true
            and panel.compact == profile[4] and controlsFit(panel)
            and textFits(panel))
        check("context/" .. profile[3],
            containsDraw(panel, "Save:")
            and containsDraw(panel, "Scenario:")
            and containsDraw(panel, "Life origin:")
            and containsDraw(panel, "Week One:"))
        check("native-preview/" .. profile[3],
            (profile[4] and panel.preview == nil)
            or (panel.preview
                and panel.preview.survivorDesc == MainScreen.instance.desc
                and panel.preview.width > 0
                and panel.preview.y + panel.preview.height
                    < panel.continueButton.y))
        if panel.compact then
            check("page/history-" .. profile[3],
                panel.backgroundEntry.visible == true
                and panel.noneButton.visible == false)
            panel.backgroundEntry:setText("An earlier life in the county.")
            panel:onClick(panel.continueButton)
            panel:prerender()
            check("page/world-" .. profile[3],
                panel.page == 2
                and panel.backgroundEntry.visible == false
                and panel.noneButton.visible == true
                and controlsFit(panel)
                and textFits(panel)
                and containsDraw(panel, "WORLD EVENT"))
            panel:onClick(panel.backButton)
            check("page/back-" .. profile[3], panel.page == 1
                and panel.backgroundEntry.visible == true
                and panel.draft.background == "An earlier life in the county.")
        end
        panel:close(true)
    end

    core.width, core.height = 800, 516
    context.scenario = 4
    context.origin = "origin-riverside"
    context.weekOneVariant = 2
    getTextOrNull = function(key)
        if key == "Sandbox_WhereIWas.ActiveScenario_option4" then
            return "Police Response"
        end
    end
    TIYL.Origins = {
        getById = function(id)
            return id == "origin-riverside" and {name = "Riverside"}
        end,
        getText = function(origin)
            return origin and origin.name or ""
        end,
    }
    BWOVariants = {[2] = {name = "Original"}}
    UI.show(source, function() end)
    local nativeLabelsPanel = UI.active
    nativeLabelsPanel:prerender()
    check("context/native-display-labels-keep-ids",
        containsDraw(nativeLabelsPanel, "Scenario: Police Response")
        and containsDraw(nativeLabelsPanel, "Life origin: Riverside")
        and containsDraw(nativeLabelsPanel, "Week One: Original")
        and nativeLabelsPanel.draft.context.scenario == 4
        and nativeLabelsPanel.draft.context.origin == "origin-riverside"
        and nativeLabelsPanel.draft.context.weekOneVariant == 2)
    nativeLabelsPanel:close(true)
    context.scenario = "A very long Where I Was scenario selection"
    context.origin = "This Is Your Life origin selected earlier"
    context.weekOneVariant = "Week One scenario chosen earlier"
    getTextOrNull = nil
    TIYL.Origins = nil
    BWOVariants = nil

    core.width, core.height = 800, 516
    UI.show(source, function() end)
    local panel = UI.active
    panel:prerender()
    check("event/optional-default-and-owned-choice",
        panel.draft.nukeChoice == "none"
        and panel.noneButton.borderColor.r == 0.67
        and panel.saoButton.borderColor.r ~= 0.67
        and containsDraw(panel, "Your choice below sets this world's strike.")
        and not containsDraw(panel, "Native Week One strike:")
        and containsDraw(panel, "Selected: No nuclear strike"))
    panel:onClick(panel.saoButton)
    panel.drawn = {}
    panel:prerender()
    check("event/explicit-enable-state", panel.draft.nukeChoice == "SAO"
        and panel.saoButton.borderColor.r == 0.67
        and panel.noneButton.borderColor.r ~= 0.67
        and containsDraw(panel, "Selected: Nuclear event"))
    panel:onClick(panel.noneButton)
    panel.backgroundEntry:setText("A life before the outbreak.")
    local nativeNext = 0
    panel.continuation = function() nativeNext = nativeNext + 1 end
    panel:onClick(panel.continueButton)
    check("native/one-continuation-with-choice", UI.active == nil
        and confirmCalls == 1 and continueCalls == 1
        and nativeNext == 1 and source.visible == false)

    core.width, core.height = 380, 420
    context.newWorld = false
    UI.show(source, function() end)
    panel = UI.active
    panel:prerender()
    check("existing-world/no-event-control", panel.noneButton == nil
        and panel.saoButton == nil and panel.draft.nukeChoice == nil
        and controlsFit(panel) and textFits(panel))
    panel:close(true)

    context.newWorld = true
    context.nativeDescriptorId = 99
    SAO.Creator.unconfirmed = {
        groupName = "Another body group", background = "Another body history",
        context = {
            world = context.world, gameMode = context.gameMode,
            newWorld = context.newWorld, forename = context.forename,
            surname = context.surname, nativeDescriptorId = 6,
            playerSlot = context.playerSlot, accountKey = context.accountKey,
            scenario = context.scenario, origin = context.origin,
            weekOneVariant = context.weekOneVariant,
        },
    }
    UI.show(source, function() end)
    panel = UI.active
    check("reopen/foreign-descriptor-draft-refused",
        panel.backgroundEntry:getText() == ""
        and panel.groupEntry:getText() == "")
    panel:close(true)
    context.nativeDescriptorId = 6

    local supplementary = string.char(0xD83D, 0xDE00)
    context.world = "0123456789" .. supplementary
        .. " selected native save"
    UI.show(source, function() end)
    panel = UI.active
    panel:prerender()
    local safe = true
    for _, row in ipairs(panel.drawn or {}) do
        if not completeUtf16(row.text) then safe = false end
    end
    check("context/utf16-truncation", safe
        and supplementary:byte(1) == 0xD83D
        and supplementary:byte(2) == 0xDE00
        and textFits(panel))
    panel:close(true)

    core.width, core.height = 640, 400
    local shown, reason = UI.show(source, function() end)
    check("small-screen/refusal-before-overlap",
        shown == false and reason == "screen-too-small-for-creation"
        and UI.active == nil)
    return tostring(passed) .. ":" .. tostring(failed)
        .. ":" .. table.concat(failures, ",")
end
