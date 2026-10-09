local function gpText(key, fallback)
    local lookup = "IGUI_ComputerMod_UI_" .. tostring(key):gsub("[^A-Za-z0-9]+", "_"):gsub("^_+", ""):gsub("_+$", "")
    if getText then
        local ok, value = pcall(getText, lookup)
        if ok and value and value ~= lookup then return value end
    end
    return fallback or key
end

local function isVisible(control)
    if not control then return false end
    local method = control.getIsVisible or control.isVisible
    if not method then return false end
    local ok, visible = pcall(function() return method(control) end)
    return ok and visible == true
end

local function controlRect(owner, control)
    if not owner or not control then return nil end
    local rootX, rootY = 0, 0
    if owner.getAbsoluteX and owner.getAbsoluteY then
        local okX, valueX = pcall(function() return owner:getAbsoluteX() end)
        local okY, valueY = pcall(function() return owner:getAbsoluteY() end)
        if okX then rootX = tonumber(valueX) or 0 end
        if okY then rootY = tonumber(valueY) or 0 end
    end
    local x = tonumber(control.x) or 0
    local y = tonumber(control.y) or 0
    if control.getAbsoluteX and control.getAbsoluteY then
        local okX, valueX = pcall(function() return control:getAbsoluteX() end)
        local okY, valueY = pcall(function() return control:getAbsoluteY() end)
        if okX then x = (tonumber(valueX) or rootX) - rootX end
        if okY then y = (tonumber(valueY) or rootY) - rootY end
    end
    local width = tonumber(control.width) or (control.getWidth and control:getWidth()) or 0
    local height = tonumber(control.height) or (control.getHeight and control:getHeight()) or 0
    return {x = x, y = y, w = width, h = height}
end

local function keyboardRows(shifted)
    local function character(value)
        return {label = shifted and string.upper(value) or value, value = value, action = "character", weight = 1}
    end
    return {
        {character("1"), character("2"), character("3"), character("4"), character("5"), character("6"), character("7"), character("8"), character("9"), character("0")},
        {character("q"), character("w"), character("e"), character("r"), character("t"), character("y"), character("u"), character("i"), character("o"), character("p")},
        {character("a"), character("s"), character("d"), character("f"), character("g"), character("h"), character("j"), character("k"), character("l"), character("@")},
        {character("z"), character("x"), character("c"), character("v"), character("b"), character("n"), character("m"), character("."), character("-"), character("_")},
        {
            {label = gpText("Shift"), action = "shift", weight = 1.6},
            {label = gpText("Space"), action = "space", weight = 2.5},
            {label = gpText("Backspace"), action = "backspace", weight = 1.7},
            {label = gpText("Enter"), action = "enter", weight = 1.5},
            {label = gpText("Done"), action = "done", weight = 1.4},
            {label = gpText("Cancel"), action = "cancel", weight = 1.6}
        }
    }
end

local function utf8Backspace(value)
    value = tostring(value or "")
    return (value:gsub("[%z\1-\127\194-\244][\128-\191]*$", ""))
end

local function readJoypadAxis(fn, joypadId)
    if not fn then return 0 end
    local ok, value = pcall(fn, joypadId)
    return ok and tonumber(value) or 0
end

local function deadzone(value)
    value = tonumber(value) or 0
    local magnitude = math.abs(value)
    if magnitude < 0.20 then return 0 end
    local normalized = math.min(1, (magnitude - 0.20) / 0.80)
    return value < 0 and -normalized or normalized
end

local function frameMillis()
    local elapsed = 16
    if UIManager and UIManager.getMillisSinceLastRender then
        local ok, value = pcall(function() return UIManager.getMillisSinceLastRender() end)
        if ok then elapsed = math.max(8, math.min(40, tonumber(value) or 16)) end
    end
    return elapsed
end

function ComputerModInstallGamepadUI(target)
    function target:getComputerGamepadControlAt(x, y)
        local children = self.childrenInOrder or self.children or {}
        for i = #children, 1, -1 do
            local child = children[i]
            if isVisible(child) and (child.Type == "ISButton" or child.Type == "ISTextEntryBox") then
                local rect = controlRect(self, child)
                if rect and x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                    return child, rect
                end
            end
        end
        return nil, nil
    end

    function target:resetComputerGamepadCursor()
        self.computerModGamepadCursorX = self.clientX and self.clientX + 24 or math.floor((self.width or 1) / 2)
        self.computerModGamepadCursorY = self.clientY and self.clientY + 24 or math.floor((self.height or 1) / 2)
        self.hoverX = self.computerModGamepadCursorX
        self.hoverY = self.computerModGamepadCursorY
    end

    function target:openComputerGamepadKeyboard(entry)
        if not entry or not isVisible(entry) then return false end
        if entry.isEditable then
            local ok, editable = pcall(function() return entry:isEditable() end)
            if ok and editable ~= true then return false end
        end
        local text = ""
        if entry.getInternalText then
            local ok, value = pcall(function() return entry:getInternalText() end)
            if ok then text = tostring(value or "") end
        elseif entry.getText then
            local ok, value = pcall(function() return entry:getText() end)
            if ok then text = tostring(value or "") end
        end
        local multipleLine = false
        local masked = false
        if entry.javaObject then
            if entry.javaObject.isMultipleLine then
                local ok, value = pcall(function() return entry.javaObject:isMultipleLine() end)
                multipleLine = ok and value == true
            end
            if entry.javaObject.isMasked then
                local ok, value = pcall(function() return entry.javaObject:isMasked() end)
                masked = ok and value == true
            end
        end
        if entry.unfocus then pcall(function() entry:unfocus() end) end
        self.computerModGamepadKeyboard = {
            entry = entry,
            text = text,
            originalText = text,
            row = 1,
            col = 1,
            shifted = false,
            multipleLine = multipleLine,
            masked = masked
        }
        self.computerModGamepadKeyboardNavDelay = 0
        return true
    end

    function target:closeComputerGamepadKeyboard(apply)
        local keyboard = self.computerModGamepadKeyboard
        if not keyboard then return end
        if apply and keyboard.entry then
            pcall(function() keyboard.entry:setText(tostring(keyboard.text or "")) end)
            if keyboard.entry.onTextChange then pcall(function() keyboard.entry:onTextChange() end) end
            if keyboard.entry.unfocus then pcall(function() keyboard.entry:unfocus() end) end
        end
        self.computerModGamepadKeyboard = nil
        self.computerModGamepadKeyboardNavDelay = nil
    end

    function target:getComputerGamepadKeyboardRects()
        local keyboard = self.computerModGamepadKeyboard
        if not keyboard then return {}, nil end
        local scale = math.max(0.8, tonumber(self.uiScale or self.contentScale) or 1)
        local panel = {
            x = self.screenX + math.floor(8 * scale),
            y = self.screenY + math.floor(8 * scale),
            w = self.screenWidth - math.floor(16 * scale),
            h = self.screenHeight - math.floor(16 * scale)
        }
        local gap = math.max(2, math.floor(3 * scale))
        local keyTop = panel.y + math.floor(57 * scale)
        local footerH = math.floor(18 * scale)
        local keyAreaH = math.max(80, panel.h - (keyTop - panel.y) - footerH)
        local rowH = math.max(18, math.floor((keyAreaH - gap * 4) / 5))
        local rows = keyboardRows(keyboard.shifted == true)
        local rects = {}
        for rowIndex = 1, #rows do
            local row = rows[rowIndex]
            local totalWeight = 0
            for colIndex = 1, #row do totalWeight = totalWeight + (row[colIndex].weight or 1) end
            local availableW = panel.w - math.floor(12 * scale) - gap * (#row - 1)
            local unitW = availableW / math.max(1, totalWeight)
            local x = panel.x + math.floor(6 * scale)
            local y = keyTop + (rowIndex - 1) * (rowH + gap)
            for colIndex = 1, #row do
                local key = row[colIndex]
                local width = math.max(12, math.floor(unitW * (key.weight or 1)))
                rects[#rects + 1] = {row = rowIndex, col = colIndex, key = key, x = x, y = y, w = width, h = rowH}
                x = x + width + gap
            end
        end
        return rects, panel
    end

    function target:activateComputerGamepadKeyboardKey(key)
        local keyboard = self.computerModGamepadKeyboard
        if not keyboard or not key then return false end
        local action = key.action
        if action == "character" then
            local value = tostring(key.value or "")
            keyboard.text = tostring(keyboard.text or "") .. (keyboard.shifted and string.upper(value) or value)
        elseif action == "space" then
            keyboard.text = tostring(keyboard.text or "") .. " "
        elseif action == "backspace" then
            keyboard.text = utf8Backspace(keyboard.text)
        elseif action == "shift" then
            keyboard.shifted = keyboard.shifted ~= true
        elseif action == "enter" then
            if keyboard.multipleLine then
                keyboard.text = tostring(keyboard.text or "") .. "\n"
            else
                self:closeComputerGamepadKeyboard(true)
            end
        elseif action == "done" then
            self:closeComputerGamepadKeyboard(true)
        elseif action == "cancel" then
            self:closeComputerGamepadKeyboard(false)
        end
        return true
    end

    function target:handleComputerGamepadDirection(direction)
        local keyboard = self.computerModGamepadKeyboard
        if not keyboard then return false end
        local rows = keyboardRows(keyboard.shifted == true)
        local row = math.max(1, math.min(#rows, tonumber(keyboard.row) or 1))
        local col = math.max(1, math.min(#rows[row], tonumber(keyboard.col) or 1))
        if direction == "left" then
            col = (col - 2) % #rows[row] + 1
        elseif direction == "right" then
            col = col % #rows[row] + 1
        elseif direction == "up" or direction == "down" then
            local oldCount = #rows[row]
            row = direction == "up" and ((row - 2) % #rows + 1) or (row % #rows + 1)
            col = math.max(1, math.min(#rows[row], math.floor(((col - 0.5) / oldCount) * #rows[row] + 0.5)))
        end
        keyboard.row = row
        keyboard.col = col
        self.computerModGamepadKeyboardNavDelay = 180
        return true
    end

    function target:handleComputerGamepadMouseDown(x, y)
        if not self.computerModGamepadKeyboard then return false end
        local rects = self:getComputerGamepadKeyboardRects()
        for i = 1, #rects do
            local rect = rects[i]
            if x >= rect.x and x <= rect.x + rect.w and y >= rect.y and y <= rect.y + rect.h then
                self.computerModGamepadKeyboard.row = rect.row
                self.computerModGamepadKeyboard.col = rect.col
                self:activateComputerGamepadKeyboardKey(rect.key)
                return true
            end
        end
        return true
    end

    function target:activateComputerGamepadCursor()
        local x = tonumber(self.computerModGamepadCursorX) or self.clientX or 0
        local y = tonumber(self.computerModGamepadCursorY) or self.clientY or 0
        local control = self:getComputerGamepadControlAt(x, y)
        if control and control.Type == "ISTextEntryBox" then
            return self:openComputerGamepadKeyboard(control)
        end
        if control and control.Type == "ISButton" and control.forceClick then
            pcall(function() control:forceClick() end)
            return true
        end
        if self.onMouseDown then pcall(function() self:onMouseDown(x, y) end) end
        if self.onMouseUp then pcall(function() self:onMouseUp(x, y) end) end
        return true
    end

    function target:openComputerGamepadContextMenu()
        local x = tonumber(self.computerModGamepadCursorX) or self.clientX or 0
        local y = tonumber(self.computerModGamepadCursorY) or self.clientY or 0
        if self.onRightMouseDown then pcall(function() self:onRightMouseDown(x, y) end) end
        return true
    end

    function target:closeComputerGamepadMenus()
        local hadMenu = self.startMenuOpen == true or self.settingsMenuOpen == true
        self.startMenuOpen = false
        self.settingsMenuOpen = false
        local fields = {
            "gameContextMenu", "discContextMenu", "folderContextMenu", "desktopContextMenu",
            "desktopItemContextMenu", "trashContextMenu", "fileItemContextMenu",
            "trashItemContextMenu", "paintFileContextMenu"
        }
        for i = 1, #fields do
            if self[fields[i]] ~= nil then hadMenu = true end
            self[fields[i]] = nil
        end
        if hadMenu and self.updateStartMenuButtons then self:updateStartMenuButtons() end
        return hadMenu
    end

    function target:computerGamepadBack()
        if self.computerModGamepadKeyboard then
            self:closeComputerGamepadKeyboard(false)
            return true
        end
        if self:closeComputerGamepadMenus() then return true end
        if ComputerModGameInput and ComputerModGameInput.hasActiveGame(self) then
            self:handleClose()
            return true
        end
        if self.currentView == "RESET_CONFIRM" or self.currentView == "DISC_WIPE_CONFIRM" then
            if self.cancelResetComputer then self:cancelResetComputer() end
            return true
        end
        if self.currentView == "BIOS" and self.exitBiosMenu then
            self:exitBiosMenu()
            return true
        end
        if self.currentView == "PASSWORD_HACK" and self.openPasswordPanel then
            self:openPasswordPanel()
            return true
        end
        if self.currentView == "NETWORK_REPAIR" and self.openNetworkTerminal then
            self:openNetworkTerminal()
            return true
        end
        if self.currentView == "GAMES" or self.currentView == "NOTEPAD" then
            self:handleClose()
            return true
        end
        if self.currentView == "DESKTOP" then
            self:hideComputerScreen()
            return true
        end
        if isVisible(self.backButton) and self.backButton.forceClick then
            self.backButton:forceClick()
            return true
        end
        local protectedView = self.currentView == "PASSWORD" or self.currentView == "LOCK"
            or self.currentView == "NETWORK_TERMINAL" or self.currentView == "BOOT_ERROR"
            or self.currentView == "HARDWARE_ERROR" or self.currentView == "OS_SETUP"
            or self.currentView == "INSTALLER" or self.currentView == "INSTALLING"
            or self.currentView == "RESETTING" or self.currentView == "DISC_WIPING"
        if not protectedView and self.bootStep >= 3 and self.backToDesktop then
            self:backToDesktop()
        else
            self:hideComputerScreen()
        end
        return true
    end

    function target:handleComputerGamepadButton(button, joypadData)
        if self.computerModGamepadKeyboard then
            if Joypad and button == Joypad.AButton then
                local keyboard = self.computerModGamepadKeyboard
                local rows = keyboardRows(keyboard.shifted == true)
                local row = math.max(1, math.min(#rows, tonumber(keyboard.row) or 1))
                local col = math.max(1, math.min(#rows[row], tonumber(keyboard.col) or 1))
                return self:activateComputerGamepadKeyboardKey(rows[row][col])
            elseif Joypad and button == Joypad.BButton then
                self:closeComputerGamepadKeyboard(false)
            elseif Joypad and button == Joypad.XButton then
                self:activateComputerGamepadKeyboardKey({action = "backspace"})
            elseif Joypad and button == Joypad.YButton then
                self:activateComputerGamepadKeyboardKey({action = "shift"})
            end
            return true
        end
        if self.errorDialog and self.errorDialog:isVisible() then
            if Joypad and (button == Joypad.AButton or button == Joypad.BButton) then self:closeError() end
            return true
        end
        if ComputerModGameInput and ComputerModGameInput.hasActiveGame(self) then
            if Joypad and button == Joypad.BButton then self:handleClose() end
            return true
        end
        if not Joypad then return true end
        if button == Joypad.AButton then
            return self:activateComputerGamepadCursor()
        elseif button == Joypad.XButton then
            return self:openComputerGamepadContextMenu()
        elseif button == Joypad.BButton then
            return self:computerGamepadBack()
        elseif button == Joypad.LBumper then
            if self.onMouseWheel then self:onMouseWheel(-1) end
            return true
        elseif button == Joypad.RBumper then
            if self.onMouseWheel then self:onMouseWheel(1) end
            return true
        end
        return true
    end

    function target:updateComputerGamepadUI()
        if not ComputerModGameInput or not ComputerModGameInput.hasGamepad(self.playerObj) then return end
        local keyboard = self.computerModGamepadKeyboard
        if keyboard then
            if not isVisible(keyboard.entry) then self:closeComputerGamepadKeyboard(false) end
            local joypadId = ComputerModGameInput.getJoypadId(self.playerObj)
            if joypadId ~= nil and self.computerModGamepadKeyboard then
                local axisX = readJoypadAxis(getJoypadMovementAxisX, joypadId)
                local axisY = readJoypadAxis(getJoypadMovementAxisY, joypadId)
                local aimX = readJoypadAxis(getJoypadAimingAxisX, joypadId)
                local aimY = readJoypadAxis(getJoypadAimingAxisY, joypadId)
                if math.abs(aimX) > math.abs(axisX) then axisX = aimX end
                if math.abs(aimY) > math.abs(axisY) then axisY = aimY end
                local povX = readJoypadAxis(getControllerPovX, joypadId)
                local povY = readJoypadAxis(getControllerPovY, joypadId)
                if math.abs(povX) > 0.1 then axisX = povX end
                if math.abs(povY) > 0.1 then axisY = povY end
                local direction = nil
                if math.abs(axisX) > math.abs(axisY) and math.abs(axisX) > 0.55 then
                    direction = axisX < 0 and "left" or "right"
                elseif math.abs(axisY) > 0.55 then
                    direction = axisY < 0 and "up" or "down"
                end
                if not direction then
                    self.computerModGamepadKeyboardNavDelay = 0
                else
                    self.computerModGamepadKeyboardNavDelay = math.max(0, (tonumber(self.computerModGamepadKeyboardNavDelay) or 0) - frameMillis())
                    if self.computerModGamepadKeyboardNavDelay <= 0 then
                        self:handleComputerGamepadDirection(direction)
                    end
                end
            end
            return
        end
        if ComputerModGameInput.hasActiveGame(self) then return end
        if self.computerModGamepadCursorX == nil or self.computerModGamepadCursorY == nil then
            self:resetComputerGamepadCursor()
        end
        local joypadId = ComputerModGameInput.getJoypadId(self.playerObj)
        if joypadId == nil then return end
        local axisX = readJoypadAxis(getJoypadMovementAxisX, joypadId)
        local axisY = readJoypadAxis(getJoypadMovementAxisY, joypadId)
        local aimX = readJoypadAxis(getJoypadAimingAxisX, joypadId)
        local aimY = readJoypadAxis(getJoypadAimingAxisY, joypadId)
        if math.abs(aimX) > math.abs(axisX) then axisX = aimX end
        if math.abs(aimY) > math.abs(axisY) then axisY = aimY end
        local povX = readJoypadAxis(getControllerPovX, joypadId)
        local povY = readJoypadAxis(getControllerPovY, joypadId)
        if math.abs(povX) > 0.1 then axisX = povX end
        if math.abs(povY) > 0.1 then axisY = povY end
        axisX = deadzone(axisX)
        axisY = deadzone(axisY)
        local elapsed = frameMillis()
        local speed = elapsed * 0.24 * math.max(1, tonumber(self.uiScale) or 1)
        self.computerModGamepadCursorX = math.max(2, math.min(self.width - 3, self.computerModGamepadCursorX + axisX * speed))
        self.computerModGamepadCursorY = math.max(2, math.min(self.height - 3, self.computerModGamepadCursorY + axisY * speed))
        self.hoverX = self.computerModGamepadCursorX
        self.hoverY = self.computerModGamepadCursorY
    end

    function target:drawComputerGamepadOverlay(canvas)
        if not ComputerModGameInput or not ComputerModGameInput.hasGamepad(self.playerObj) then return end
        local keyboard = self.computerModGamepadKeyboard
        if keyboard then
            local rects, panel = self:getComputerGamepadKeyboardRects()
            if not panel then return end
            canvas:drawRect(self.screenX, self.screenY, self.screenWidth, self.screenHeight, 0.88, 0, 0, 0)
            canvas:drawRect(panel.x, panel.y, panel.w, panel.h, 1, 0.055, 0.060, 0.070)
            canvas:drawRect(panel.x, panel.y, panel.w, 2, 1, 0.62, 0.66, 0.72)
            canvas:drawText(gpText("Gamepad keyboard"), panel.x + 8, panel.y + 5, 0.82, 0.86, 0.92, 1, UIFont.Small)
            local preview = tostring(keyboard.text or ""):gsub("\n", " ")
            if keyboard.masked then preview = string.rep("*", math.min(48, #preview)) end
            if #preview > 58 then preview = "..." .. string.sub(preview, #preview - 54) end
            canvas:drawRect(panel.x + 6, panel.y + 23, panel.w - 12, 27, 1, 0.012, 0.016, 0.022)
            canvas:drawText(preview .. "_", panel.x + 11, panel.y + 29, 0.72, 0.88, 0.78, 1, UIFont.Small)
            for i = 1, #rects do
                local rect = rects[i]
                local selected = rect.row == keyboard.row and rect.col == keyboard.col
                canvas:drawRect(rect.x, rect.y, rect.w, rect.h, 1, selected and 0.28 or 0.16, selected and 0.34 or 0.18, selected and 0.42 or 0.22)
                local borderR, borderG, borderB = selected and 0.96 or 0.38, selected and 0.84 or 0.42, selected and 0.32 or 0.48
                canvas:drawRectBorder(rect.x, rect.y, rect.w, rect.h, 1, borderR, borderG, borderB)
                local label = tostring(rect.key.label or "")
                local textW = getTextManager():MeasureStringX(UIFont.Small, label)
                canvas:drawText(label, rect.x + math.floor((rect.w - textW) / 2), rect.y + math.floor((rect.h - 14) / 2), 0.90, 0.92, 0.94, 1, UIFont.Small)
            end
            canvas:drawText("A " .. gpText("Select") .. "   X " .. gpText("Backspace") .. "   Y " .. gpText("Shift") .. "   B " .. gpText("Cancel"), panel.x + 8, panel.y + panel.h - 16, 0.58, 0.64, 0.70, 1, UIFont.Small)
            return
        end
        if ComputerModGameInput.hasActiveGame(self) then return end
        if self.computerModGamepadCursorX == nil then self:resetComputerGamepadCursor() end
        local x = math.floor(self.computerModGamepadCursorX)
        local y = math.floor(self.computerModGamepadCursorY)
        local _, rect = self:getComputerGamepadControlAt(x, y)
        if rect then
            canvas:drawRectBorder(rect.x - 2, rect.y - 2, rect.w + 4, rect.h + 4, 0.95, 0.94, 0.86, 0.30)
            canvas:drawRectBorder(rect.x - 1, rect.y - 1, rect.w + 2, rect.h + 2, 0.95, 0.94, 0.86, 0.30)
        end
        canvas:drawRect(x + 2, y + 2, 3, 16, 0.75, 0, 0, 0)
        canvas:drawRect(x + 5, y + 5, 3, 11, 0.75, 0, 0, 0)
        canvas:drawRect(x + 8, y + 8, 3, 7, 0.75, 0, 0, 0)
        canvas:drawRect(x, y, 2, 15, 1, 0.94, 0.96, 0.98)
        canvas:drawRect(x + 2, y + 2, 2, 12, 1, 0.94, 0.96, 0.98)
        canvas:drawRect(x + 4, y + 4, 2, 9, 1, 0.94, 0.96, 0.98)
        canvas:drawRect(x + 6, y + 6, 2, 5, 1, 0.94, 0.96, 0.98)
    end
end
