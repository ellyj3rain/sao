require "ISUI/ISPanelJoypad"
require "ISUI/ISButton"
require "ISUI/ISTextEntryBox"
require "OptionScreens/CharacterCreationAvatar"
require "SAO_PlayerCreator"

local C = SAO.Creator
C.UI = C.UI or {}
local UI = C.UI

local Panel = ISPanelJoypad:derive("SAOPlayerCreatorPanel")
local ACCENT = {r = 0.67, g = 0.84, b = 0.78}
local PANEL = {r = 0.055, g = 0.075, b = 0.083}
local MUTED = {r = 0.77, g = 0.82, b = 0.81}

local function visible(screen, value)
    if screen and screen.setVisible then screen:setVisible(value) end
end

local function button(owner, x, y, width, title, internal)
    local b = ISButton:new(x, y, width, 34, title, owner, Panel.onClick)
    b.internal = internal
    b:initialise()
    b:instantiate()
    b.backgroundColor = {r = 0.10, g = 0.15, b = 0.16, a = 0.95}
    b.borderColor = {r = 0.34, g = 0.44, b = 0.44, a = 0.9}
    owner:addChild(b)
    return b
end

local function entry(owner, x, y, width, height, value, multiline)
    local e = ISTextEntryBox:new(value or "", x, y, width, height)
    e:initialise()
    e:instantiate()
    if multiline then e:setMultipleLine(true); e:setMaxLines(8) end
    owner:addChild(e)
    return e
end

local function labelValue(value)
    if value == nil or value == "" then return "Native choice" end
    return tostring(value)
end

-- Resolve the selected native labels for display only. Context identity and
-- confirmation continue to use the original IDs held by SAO_PlayerCreator.
local function nativeLabels(source, context)
    local labels = {}
    if type(context.scenario) == "number"
        and type(getTextOrNull) == "function" then
        local key = "Sandbox_WhereIWas.ActiveScenario_option"
            .. tostring(context.scenario)
        local ok, translated = pcall(getTextOrNull, key)
        if ok and type(translated) == "string" and translated ~= "" then
            labels.scenario = translated
        end
    end
    local origins = TIYL and TIYL.Origins
    if context.origin ~= nil and origins
        and type(origins.getById) == "function"
        and type(origins.getText) == "function" then
        local ok, translated = pcall(function()
            return origins.getText(origins.getById(context.origin), "name")
        end)
        if ok and type(translated) == "string" and translated ~= "" then
            labels.origin = translated
        end
    end
    local selected = context.weekOneVariant
    local variants = BWOVariants
    local item = type(variants) == "table" and variants[selected]
    if source and source.variantListBox
        and source.variantListBox.selected == selected then
        -- The selected source list is already on the native creator path.
        local row = source.variantListBox.items
            and source.variantListBox.items[selected]
        if row and row.item and row.item.index == selected then
            item = row.item
        end
    end
    if item and type(item.name) == "string" and item.name ~= "" then
        labels.weekOneVariant = item.name
    end
    return labels
end

local function fitText(text, width, font)
    local manager = getTextManager()
    text = tostring(text)
    if manager:MeasureStringX(font, text) <= width then return text end
    while #text > 0
        and manager:MeasureStringX(font, text .. "...") > width do
        -- Kahlua strings use Java UTF-16 code units. Remove a complete
        -- surrogate pair when the last character uses two units.
        local cut = #text
        local last = text:byte(cut)
        if last >= 0xDC00 and last <= 0xDFFF then cut = cut - 1 end
        text = text:sub(1, cut - 1)
    end
    return text .. "..."
end

local function layout(width, height, newWorld)
    local narrow = width < 700
    local compact = height < 500 or narrow
    local inset = narrow and 18 or 24
    local leftW = narrow and 0
        or math.floor((width - inset * 3) * 0.42)
    local contentX = narrow and inset or inset * 2 + leftW
    local contentW = width - contentX - inset
    local footerY = height - 56
    local shortNarrow = narrow and height < 400
    local groupY = narrow and (shortNarrow and 166 or 193)
        or (compact and 151 or 158)
    local backgroundY = narrow and (shortNarrow and 226 or 258)
        or (compact and 226 or 233)
    local choiceY = compact and math.max(200, footerY - 84)
        or footerY - 70
    local worldTitleY = compact and (narrow and 165 or 124)
        or choiceY - 49
    local backgroundEnd = newWorld and not compact
        and worldTitleY - 14 or footerY - 16
    return {
        compact = compact, narrow = narrow, inset = inset,
        leftW = leftW, contentX = contentX, contentW = contentW,
        footerY = footerY, groupY = groupY,
        backgroundY = backgroundY, backgroundH = backgroundEnd - backgroundY,
        choiceY = choiceY, worldTitleY = worldTitleY,
    }
end

function Panel:new(source, continuation, draft)
    local width = math.min(1050, getCore():getScreenWidth() - 16)
    local height = math.min(720, getCore():getScreenHeight() - 16)
    local x = math.floor((getCore():getScreenWidth() - width) / 2)
    local y = math.floor((getCore():getScreenHeight() - height) / 2)
    local o = ISPanelJoypad:new(x, y, width, height)
    setmetatable(o, self)
    self.__index = self
    o.source = source
    o.continuation = continuation
    o.draft = draft
    o.nativeLabels = nativeLabels(source, draft.context)
    o.backgroundColor = {r = PANEL.r, g = PANEL.g, b = PANEL.b, a = 0.98}
    o.borderColor = {r = ACCENT.r, g = ACCENT.g, b = ACCENT.b, a = 0.9}
    o.moveWithMouse = false
    o.wantKeyEvents = true
    o.layout = layout(width, height, draft.context.newWorld)
    o.compact = o.layout.compact
    o.singleColumn = o.layout.narrow
    o.page = 1
    return o
end

function Panel:createChildren()
    local place = self.layout
    local inset = place.inset
    local main = MainScreen and MainScreen.instance
    if not self.singleColumn and self.height >= 500
        and CharacterCreationAvatar and main and main.desc then
        -- The installed native viewer reads the descriptor already selected.
        local ok, viewer = pcall(function()
            local item = CharacterCreationAvatar:new(inset + 16, 278,
                place.leftW - 32, place.footerY - 290)
            item:initialise()
            self:addChild(item)
            item:setSurvivorDesc(main.desc)
            item:rescaleAvatarViewer()
            return item
        end)
        if ok then self.preview = viewer
        elseif SAO.Log and SAO.Log.line then
            SAO.Log.line("CREATOR", "native preview unavailable: "
                .. tostring(viewer))
        end
    end
    self.groupEntry = entry(self, place.contentX, place.groupY,
        place.contentW, 32,
        self.draft.groupName, false)
    self.backgroundEntry = entry(self, place.contentX, place.backgroundY,
        place.contentW, place.backgroundH,
        self.draft.background, true)
    if self.draft.context.newWorld then
        local half = math.floor((place.contentW - 10) / 2)
        self.noneButton = button(self, place.contentX,
            place.choiceY, half,
            "No nuclear strike", "NUKE_NONE")
        self.saoButton = button(self, place.contentX + half + 10,
            place.choiceY, half,
            "Nuclear event", "NUKE_SAO")
    end
    local footerWidth = math.floor((self.width - inset * 3) / 2)
    self.backButton = button(self, inset, place.footerY,
        math.min(142, footerWidth),
        "Back to choices", "BACK")
    local continueWidth = math.min(180, footerWidth)
    self.continueButton = button(self, self.width - inset - continueWidth,
        place.footerY, continueWidth, "Create character", "CONTINUE")
    self:updatePage()
end

local function selectButton(button, selected)
    if not button then return end
    button.borderColor = selected
        and {r = ACCENT.r, g = ACCENT.g, b = ACCENT.b, a = 1}
        or {r = 0.34, g = 0.44, b = 0.44, a = 0.9}
    button.backgroundColor = selected
        and {r = 0.16, g = 0.25, b = 0.23, a = 0.98}
        or {r = 0.10, g = 0.15, b = 0.16, a = 0.95}
end

function Panel:updatePage()
    local history = not self.compact or self.page == 1
    if not history then
        if self.groupEntry.unfocus then self.groupEntry:unfocus() end
        if self.backgroundEntry.unfocus then self.backgroundEntry:unfocus() end
    end
    self.groupEntry:setVisible(history)
    self.backgroundEntry:setVisible(history)
    if self.noneButton then
        self.noneButton:setVisible(not self.compact or self.page == 2)
        self.saoButton:setVisible(not self.compact or self.page == 2)
        selectButton(self.noneButton, self.draft.nukeChoice == "none")
        selectButton(self.saoButton, self.draft.nukeChoice == "SAO")
    end
    self.continueButton:setTitle(self.compact and self.page == 1
        and self.draft.context.newWorld and "World choice"
        or "Create character")
    if self.joyfocus then self:loadJoypadButtons(self.joyfocus) end
end

function Panel:loadJoypadButtons(joypadData)
    if joypadData then self:clearJoypadFocus(joypadData) end
    self.joypadButtonsY = {}
    self.allJoypadButtons = {}
    if not self.compact or self.page == 1 then
        self:insertNewLineOfButtons(self.groupEntry)
        self:insertNewLineOfButtons(self.backgroundEntry)
    end
    if self.noneButton and (not self.compact or self.page == 2) then
        self:insertNewLineOfButtons(self.noneButton, self.saoButton)
    end
    self:insertNewLineOfButtons(self.backButton, self.continueButton)
    self.joypadIndex = 1
    self.joypadIndexY = 1
    self.joypadButtons = self.joypadButtonsY[1]
    self:clearISButtons()
    self:setISButtonForA(self.continueButton)
    self:setISButtonForB(self.backButton)
end

function Panel:onGainJoypadFocus(joypadData)
    ISPanelJoypad.onGainJoypadFocus(self, joypadData)
    self:loadJoypadButtons(joypadData)
end

function Panel:onLoseJoypadFocus(joypadData)
    self:clearISButtons()
    ISPanelJoypad.onLoseJoypadFocus(self, joypadData)
end

function Panel:onKeyRelease(key)
    if key == Keyboard.KEY_ESCAPE then
        self:onClick(self.backButton)
    elseif key == Keyboard.KEY_TAB then
        if self.groupEntry.isFocused
            and self.groupEntry:isFocused() then
            self.groupEntry:unfocus()
            self.backgroundEntry:focus()
        elseif self.backgroundEntry.isFocused
            and self.backgroundEntry:isFocused() then
            self.backgroundEntry:unfocus()
            if self.noneButton and (not self.compact or self.page == 2) then
                self.keyboardChoice = "none"
            end
        elseif self.keyboardChoice == "none" then
            self.keyboardChoice = "SAO"
        elseif self.keyboardChoice == "SAO" then
            self.keyboardChoice = nil
            if not self.compact or self.page == 1 then
                self.groupEntry:focus()
            end
        elseif not self.compact or self.page == 1 then
            self.groupEntry:focus()
        elseif self.noneButton then
            self.keyboardChoice = "none"
        end
    elseif key == Keyboard.KEY_RETURN then
        if self.keyboardChoice == "none" then
            self:onClick(self.noneButton)
            self.keyboardChoice = nil
        elseif self.keyboardChoice == "SAO" then
            self:onClick(self.saoButton)
            self.keyboardChoice = nil
        elseif not (self.backgroundEntry.isFocused
            and self.backgroundEntry:isFocused()) then
            self:onClick(self.continueButton)
        end
    end
end

function Panel:sync()
    self.draft.groupName = self.groupEntry:getText()
    self.draft.background = self.backgroundEntry:getText()
end

function Panel:close(restore)
    self:setVisible(false)
    local main = MainScreen and MainScreen.instance
    if main and main.removeChild then main:removeChild(self) end
    if restore then visible(self.source, true) end
    if UI.active == self then UI.active = nil end
end

function Panel:onClick(clicked)
    if clicked.internal == "BACK" then
        if self.compact and self.page == 2 then
            self.page = 1
            self.keyboardChoice = nil
            self:updatePage()
            return
        end
        self:sync()
        C.unconfirmed = self.draft
        C.pending = nil
        self:close(true)
        return
    end
    if clicked.internal == "NUKE_NONE" then
        self.draft.nukeChoice = "none"
        self.error = nil
        self:updatePage()
        return
    end
    if clicked.internal == "NUKE_SAO" then
        self.draft.nukeChoice = "SAO"
        self.error = nil
        self:updatePage()
        return
    end
    if clicked.internal ~= "CONTINUE" then return end
    if not self.compact or self.page == 1 then self:sync() end
    if self.compact and self.page == 1
        and self.draft.context.newWorld then
        if not self.draft.background
            or self.draft.background:match("^%s*$") then
            self.error = "background-required"
            return
        end
        self.page = 2
        self.keyboardChoice = nil
        self.error = nil
        self:updatePage()
        return
    end
    local ok, reason = C.confirm(self.draft, self.source)
    if not ok then self.error = reason; return end
    local advanced, why = C.continueConfirmed(self.source, self.continuation)
    if not advanced then
        self.error = why
        return
    end
    self:close(false)
end

function Panel:prerender()
    ISPanelJoypad.prerender(self)
    local place = self.layout
    local inset = place.inset
    local contentX, contentW = place.contentX, place.contentW
    local ctx = self.draft.context
    if not place.narrow then
        self:drawRect(inset, 80, place.leftW,
            place.footerY - 92, 0.9, 0.11, 0.16, 0.18)
        self:drawRect(inset, 80, 4, place.footerY - 92, 0.95,
            ACCENT.r, ACCENT.g, ACCENT.b)
        self:drawRect(contentX, 80, contentW,
            place.footerY - 92, 0.7, 0.09, 0.13, 0.14)
    else
        self:drawRect(inset, 77, contentW, 68, 0.9,
            0.11, 0.16, 0.18)
        self:drawRect(inset, 77, 3, 68, 0.95,
            ACCENT.r, ACCENT.g, ACCENT.b)
    end
    self:drawText("YOUR SURVIVOR", inset, 22, ACCENT.r,
        ACCENT.g, ACCENT.b, 1, UIFont.Large)
    local subtitle = self.error and (self.error == "background-required"
        and "Enter a personal history to continue."
        or "Please review the creation choice: " .. tostring(self.error))
        or "Appearance, traits and profession use your native selection."
    self:drawText(fitText(subtitle, self.width - inset * 2,
        UIFont.Small), inset, 53,
        self.error and 1 or MUTED.r,
        self.error and 0.46 or MUTED.g,
        self.error and 0.40 or MUTED.b, 1, UIFont.Small)
    if not place.narrow then
        local textX = inset + 18
        local textW = place.leftW - 36
        self:drawText(fitText(ctx.forename .. " " .. ctx.surname,
            textW, UIFont.Large), textX, 105,
            1, 1, 1, 1, UIFont.Large)
        self:drawText(fitText("Save: " .. labelValue(ctx.world),
            textW, UIFont.Small), textX, 153,
            MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        self:drawText(fitText("Scenario: "
            .. labelValue(self.nativeLabels.scenario or ctx.scenario),
            textW, UIFont.Small), textX, 180,
            MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        self:drawText(fitText("Life origin: "
            .. labelValue(self.nativeLabels.origin or ctx.origin),
            textW, UIFont.Small), textX, 207,
            MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        self:drawText(fitText("Week One: "
            .. labelValue(self.nativeLabels.weekOneVariant
                or ctx.weekOneVariant),
            textW, UIFont.Small), textX, 234,
            MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        if self.height >= 500 and not self.preview then
            self:drawText("Native preview unavailable", textX, 292,
                MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        end
    else
        self:drawText(fitText(ctx.forename .. " " .. ctx.surname,
            contentW - 32, UIFont.Large), contentX + 16, 83,
            1, 1, 1, 1, UIFont.Large)
        local cellW = math.floor((contentW - 42) / 2)
        local leftX = contentX + 16
        local rightX = leftX + cellW + 10
        local choices = {
            {"Save: " .. labelValue(ctx.world), leftX, 115},
            {"Scenario: " .. labelValue(self.nativeLabels.scenario
                or ctx.scenario), rightX, 115},
            {"Life origin: " .. labelValue(self.nativeLabels.origin
                or ctx.origin), leftX, 134},
            {"Week One: " .. labelValue(self.nativeLabels.weekOneVariant
                or ctx.weekOneVariant), rightX, 134},
        }
        for _, choice in ipairs(choices) do
            self:drawText(fitText(choice[1], cellW, UIFont.Small),
                choice[2], choice[3],
                MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        end
    end
    if not self.compact or self.page == 1 then
        if not (place.narrow and self.height < 400) then
            self:drawText("PERSONAL HISTORY", contentX + 12,
                place.narrow and 153 or 103,
                ACCENT.r, ACCENT.g, ACCENT.b, 1, UIFont.Medium)
        end
        self:drawText("Group name (optional)", contentX + 12,
            place.groupY - 23,
            0.86, 0.89, 0.87, 1, UIFont.Small)
        self:drawText(fitText("What did this person carry into the outbreak?",
            contentW - 24, UIFont.Small), contentX + 12,
            place.backgroundY - 22,
            0.86, 0.89, 0.87, 1, UIFont.Small)
    end
    if ctx.newWorld and (not self.compact or self.page == 2) then
        self:drawText("WORLD EVENT (OPTIONAL)",
            contentX + 12, place.worldTitleY,
            ACCENT.r, ACCENT.g, ACCENT.b,
            1, UIFont.Medium)
        self:drawText(fitText("Your choice below sets this world's strike.",
            contentW - 24, UIFont.Small),
            contentX + 12, place.worldTitleY + 23,
            MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        local selection = self.draft.nukeChoice == "SAO"
            and "Nuclear event" or "No nuclear strike"
        self:drawText("Selected: " .. selection,
            contentX + 12, place.choiceY + 40,
            ACCENT.r, ACCENT.g, ACCENT.b, 1, UIFont.Small)
        if self.keyboardChoice then
            self:drawText(fitText("Focus: "
                .. (self.keyboardChoice == "SAO" and "Nuclear event"
                    or "No nuclear strike"),
                math.floor(contentW / 2) - 12, UIFont.Small),
                contentX + math.floor(contentW / 2),
                place.choiceY + 40,
                MUTED.r, MUTED.g, MUTED.b, 1, UIFont.Small)
        end
    end
end

function UI.show(screen, continuation)
    if getCore():getScreenHeight() < 356
        or getCore():getScreenWidth() < 380
        or (getCore():getScreenWidth() < 716
            and getCore():getScreenHeight() < 420) then
        return false, "screen-too-small-for-creation"
    end
    local draft, reason = C.newDraft(screen)
    if not draft then return false, reason end
    if C.unconfirmed and C.unconfirmed.context
        and C.unconfirmed.context.world == draft.context.world
        and C.unconfirmed.context.gameMode == draft.context.gameMode
        and C.unconfirmed.context.newWorld == draft.context.newWorld
        and C.unconfirmed.context.forename == draft.context.forename
        and C.unconfirmed.context.surname == draft.context.surname
        and C.unconfirmed.context.nativeDescriptorId
            == draft.context.nativeDescriptorId
        and C.unconfirmed.context.playerSlot == draft.context.playerSlot
        and C.unconfirmed.context.accountKey == draft.context.accountKey
        and C.unconfirmed.context.scenario == draft.context.scenario
        and C.unconfirmed.context.origin == draft.context.origin
        and C.unconfirmed.context.weekOneVariant
            == draft.context.weekOneVariant then
        draft.groupName = C.unconfirmed.groupName or ""
        draft.background = C.unconfirmed.background or ""
        draft.nukeChoice = C.unconfirmed.nukeChoice
    end
    if UI.active then UI.active:close(false) end
    local main = MainScreen and MainScreen.instance
    if not main or not main.addChild then return false, "native-menu-unavailable" end
    local panel = Panel:new(screen, continuation, draft)
    panel:initialise()
    main:addChild(panel)
    visible(screen, false)
    local joypadData = JoypadState and JoypadState.getMainMenuJoypad
        and JoypadState.getMainMenuJoypad()
        or CoopCharacterCreation and CoopCharacterCreation.getJoypad
            and CoopCharacterCreation.getJoypad() or nil
    panel:setVisible(true, joypadData)
    UI.active = panel
    C.unconfirmed = nil
    return true
end

return UI
