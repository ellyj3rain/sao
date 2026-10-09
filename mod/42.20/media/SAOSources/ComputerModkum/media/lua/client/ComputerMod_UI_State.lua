function ComputerModInstallUIState(target)
    local shared = ComputerModUIShared or {}
    local styleRetroButton = shared.styleRetroButton
    local styleIconButton = shared.styleIconButton
    local getGameClockText = shared.getGameClockText
    local getGameDateText = shared.getGameDateText
    local getComputerTimeStep = shared.getComputerTimeStep
    local playComputerUISound = shared.playComputerUISound
    local getComputerWorldAgeHours = shared.getComputerWorldAgeHours
    local addItemWithSavedName = shared.addItemWithSavedName
    local tr = shared.tr or function(key, fallback) return fallback or key end
    local isDebugModeEnabled = shared.isDebugModeEnabled
    local isPlayerNearComputer = shared.isPlayerNearComputer
    local hasComputerPower = shared.hasComputerPower
    local applyEntryColors = shared.applyEntryColors
    local bootMessages = shared.bootMessages
    local browserSites = shared.browserSites
    local browserSiteOrder = shared.browserSiteOrder
    local publicBrowserSiteOrder = shared.publicBrowserSiteOrder
    local desktopFilesTexture = shared.desktopFilesTexture
    local desktopNoteTexture = shared.desktopNoteTexture
    local desktopBrowserTexture = shared.desktopBrowserTexture
    local desktopCalculatorTexture = shared.desktopCalculatorTexture
    local desktopFolderTexture = shared.desktopFolderTexture
    local desktopSettingsTexture = shared.desktopSettingsTexture
    local cdTexture = shared.cdTexture
    local desktopMailTexture = shared.desktopMailTexture
    local desktopTrashTexture = shared.desktopTrashTexture
    local desktopMusicTexture = shared.desktopMusicTexture
    local desktopPaintTexture = shared.desktopPaintTexture
    local gamesPongTexture = shared.gamesPongTexture
    local gamesSnakeTexture = shared.gamesSnakeTexture
    local gamesMinesTexture = shared.gamesMinesTexture
    local gamesTetrisTexture = shared.gamesTetrisTexture
    local gamesDoomTexture = shared.gamesDoomTexture
    local gamesInvadersTexture = shared.gamesInvadersTexture
    local gamesRacerTexture = shared.gamesRacerTexture
    local gamesFlappyTexture = shared.gamesFlappyTexture
    local gamesBreakoutTexture = shared.gamesBreakoutTexture
    local gamesAsteroidsTexture = shared.gamesAsteroidsTexture
    local gamesFroggerTexture = shared.gamesFroggerTexture
    local gamesCircuitTexture = shared.gamesCircuitTexture
    local startIconTexture = shared.startIconTexture
    local userTextures = shared.userTextures
    local easyComputerPasswords = shared.easyComputerPasswords
    local periodComputerNames = shared.periodComputerNames
    local backgroundPalettes = shared.backgroundPalettes
    local textSizeScales = shared.textSizeScales or {0.90, 1.00, 1.15, 1.30, 1.45}
    local uiScaleOptions = shared.uiScaleOptions or {0, 1.00, 1.25, 1.50, 1.75, 2.00, 2.50}
    local gameInstallOrder = shared.gameInstallOrder
    local gameInstallInfo = shared.gameInstallInfo
    local gameDownloadInfo = shared.gameDownloadInfo
    local gameDiscItems = shared.gameDiscItems
    local appEntryLabels = {
        files = "My Files",
        notepad = "Notepad",
        browser = "Browser",
        calculator = "Calculator",
        games = "Games",
        board = "Board",
        trash = "Trash",
        music = "Music",
        mail = "Mail",
        chat = "Chat",
        settings = "Settings",
        paint = "Paint"
    }

local function cloneComputerEntry(entry)
    local copy = {}
    if type(entry) ~= "table" then return copy end
    for k, v in pairs(entry) do
        if type(v) == "table" then
            local nested = {}
            for nk, nv in pairs(v) do
                nested[nk] = nv
            end
            copy[k] = nested
        else
            copy[k] = v
        end
    end
    return copy
end

local function entryKeyForHiddenDesktop(entry)
    if not entry then return nil end
    if entry.kind == "app" or entry.type == "app" then
        local app = entry.app or entry.id
        return app and ("app_" .. tostring(app)) or nil
    end
    if entry.kind == "folder" or entry.type == "folder" then
        local name = entry.folderName or entry.name
        return name and ("folder:" .. tostring(name)) or nil
    end
    if entry.kind == "note" or entry.type == "note" then
        local key = entry.noteKey or entry.key
        return key and ("note:" .. tostring(key)) or nil
    end
    if entry.kind == "paint" or entry.type == "paint" then
        local key = entry.paintKey or entry.key
        return key and ("paint:" .. tostring(key)) or nil
    end
    return entry.key
end

function target:getHiddenDesktopItems()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModHiddenDesktopItems) ~= "table" then
        data.ComputerModHiddenDesktopItems = {}
    end
    return data.ComputerModHiddenDesktopItems
end

function target:getDesktopStoredFiles()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModDesktopFiles) ~= "table" then
        data.ComputerModDesktopFiles = {}
    end
    local filtered = {}
    for i = 1, #data.ComputerModDesktopFiles do
        local entry = data.ComputerModDesktopFiles[i]
        if entry and entry.type == "magazine" and entry.id and self:isValidMagazineType(entry.id) then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "newspaper" and entry.id and self:isValidNewspaperId(entry.id) then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "video" and entry.id and self:isValidVideoId(entry.id) then
            filtered[#filtered + 1] = entry
        end
    end
    data.ComputerModDesktopFiles = filtered
    return data.ComputerModDesktopFiles
end

function target:generateDesktopFileKey()
    local base = getTimestampMs and getTimestampMs() or math.floor((getComputerWorldAgeHours and getComputerWorldAgeHours()) or 0)
    return "file_" .. tostring(base) .. "_" .. tostring(1000 + ZombRand(9000))
end

function target:addEntryToDesktop(entry)
    if not entry then return false end
    if entry.type == "app" then return false end
    if entry.type == "folder" then
        self:setDesktopItemHidden("folder:" .. tostring(entry.name), false)
        return true
    end
    if entry.type == "note" then
        if entry.key and not self:getDesktopNoteByKey(entry.key) then
            local data = self:getComputerData()
            local notes = self:getDesktopNotes()
            notes[#notes + 1] = {key = entry.key, name = entry.label or "Note", text = entry.text or ""}
            if data then data.ComputerModDesktopNotes = notes end
        end
        if entry.key then
            self:setDesktopItemHidden("note:" .. tostring(entry.key), false)
        end
        return true
    end
    if entry.type == "paint" then
        if entry.key and not self:getPaintFileByKey(entry.key) then
            local data = self:getComputerData()
            local files = self:getPaintFiles()
            files[#files + 1] = {key = entry.key, name = entry.label or "Drawing", width = entry.width or 32, height = entry.height or 18, cells = entry.cells or {}}
            if data then data.ComputerModPaintFiles = files end
        end
        if entry.key then
            self:setDesktopItemHidden("paint:" .. tostring(entry.key), false)
        end
        return true
    end
    if entry.type == "magazine" or entry.type == "newspaper" or entry.type == "video" then
        local files = self:getDesktopStoredFiles()
        local copy = cloneComputerEntry(entry)
        copy.desktopKey = copy.desktopKey or self:generateDesktopFileKey()
        for i = 1, #files do
            if files[i] and files[i].desktopKey == copy.desktopKey then
                copy.desktopKey = self:generateDesktopFileKey()
                break
            end
        end
        files[#files + 1] = copy
        local data = self:getComputerData()
        if data then
            data.ComputerModDesktopFiles = files
            data.ComputerModFactoryReset = false
        end
        return true
    end
    return false
end

function target:removeDesktopStoredFile(desktopKey)
    if not desktopKey then return false end
    local data = self:getComputerData()
    if not data then return false end
    local files = self:getDesktopStoredFiles()
    for i = #files, 1, -1 do
        if files[i] and files[i].desktopKey == desktopKey then
            table.remove(files, i)
            data.ComputerModDesktopFiles = files
            return true
        end
    end
    return false
end

function target:isDesktopItemHidden(itemKey)
    if not itemKey then return false end
    local hidden = self:getHiddenDesktopItems()
    return hidden[itemKey] == true
end

function target:setDesktopItemHidden(itemKey, hiddenValue)
    if not itemKey then return end
    local data = self:getComputerData()
    if not data then return end
    local hidden = self:getHiddenDesktopItems()
    if hiddenValue then
        hidden[itemKey] = true
    else
        hidden[itemKey] = nil
    end
    data.ComputerModHiddenDesktopItems = hidden
end

function target:isDiscStorageOpenable()
    local data = self:getComputerData()
    if not data then return false end
    return data.ComputerModMountedCD == "blank"
end

function target:getMountedDiscContents()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModMountedCDContents) ~= "table" then
        data.ComputerModMountedCDContents = {}
    end
    local filtered = {}
    for i = 1, #data.ComputerModMountedCDContents do
        local entry = data.ComputerModMountedCDContents[i]
        if entry and entry.type ~= "app" then
            filtered[#filtered + 1] = entry
        end
    end
    data.ComputerModMountedCDContents = filtered
    return data.ComputerModMountedCDContents
end

function target:getStorageEntries(storageName)
    if storageName == "__CD__" then
        return self:getMountedDiscContents()
    end
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModFolderContents) ~= "table" then data.ComputerModFolderContents = {} end
    storageName = tostring(storageName or "")
    data.ComputerModFolderContents[storageName] = data.ComputerModFolderContents[storageName] or {}
    return data.ComputerModFolderContents[storageName]
end

function target:getStorageDisplayName(storageName)
    if storageName == "__CD__" then
        local data = self:getComputerData()
        return (data and data.ComputerModMountedCDLabel) or "Blank CD (D:)"
    end
    return storageName or "Folder"
end

function target:getDesktopFileEntry(item)
    if not item then return nil end
    if item.kind == "app" then
        return nil
    end
    if item.kind == "folder" then
        return {type = "folder", name = item.folderName, label = item.label or item.folderName}
    end
    if item.kind == "note" then
        local note = self:getDesktopNoteByKey(item.noteKey)
        return {type = "note", key = item.noteKey, label = item.label or "Note", text = note and note.text or ""}
    end
    if item.kind == "paint" then
        local file = self:getPaintFileByKey(item.paintKey)
        return {type = "paint", key = item.paintKey, label = item.label or "Drawing", width = file and file.width or nil, height = file and file.height or nil, cells = file and file.cells or nil}
    end
    if item.kind == "stored" and item.entry then
        return cloneComputerEntry(item.entry)
    end
    return nil
end

function target:isEntryAllowedOnDisc(entry)
    return entry and entry.type ~= "app"
end

function target:addEntryToStorage(entry, storageName)
    if not entry or not storageName or storageName == "" then return false end
    if storageName == "__CD__" and not self:isEntryAllowedOnDisc(entry) then
        self:showError(tr("Applications cannot be copied to CD."))
        return false
    end
    local entries = self:getStorageEntries(storageName)
    entries[#entries + 1] = cloneComputerEntry(entry)
    local data = self:getComputerData()
    if data then
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    return true
end

function target:removeDesktopFileEntry(entry)
    local data = self:getComputerData()
    if not data or not entry then return false end
    if entry.type == "app" then
        self:setDesktopItemHidden("app_" .. tostring(entry.app), true)
        return true
    end
    if entry.type == "folder" and entry.name and entry.name ~= "Downloads" then
        self:setDesktopItemHidden("folder:" .. tostring(entry.name), true)
        return true
    end
    if entry.type == "note" and entry.key then
        self:setDesktopItemHidden("note:" .. tostring(entry.key), true)
        return true
    end
    if entry.type == "paint" and entry.key then
        self:setDesktopItemHidden("paint:" .. tostring(entry.key), true)
        return true
    end
    if (entry.type == "magazine" or entry.type == "newspaper" or entry.type == "video") and entry.desktopKey then
        return self:removeDesktopStoredFile(entry.desktopKey)
    end
    return false
end

function target:deleteDesktopItem(item)
    local data = self:getComputerData()
    if not data or not item or item.kind == "app" then return false end
    if item.kind == "folder" then
        local folders = self:getComputerFolders()
        for i = #folders, 1, -1 do
            if folders[i] == item.folderName and folders[i] ~= "Downloads" then
                self:addFolderToTrash(folders[i], "desktop", nil)
                table.remove(folders, i)
                data.ComputerModFolders = folders
                if data.ComputerModFolderContents then
                    data.ComputerModFolderContents[item.folderName] = nil
                end
                if data.ComputerModUserFolders then
                    data.ComputerModUserFolders[item.folderName] = nil
                end
                self:setDesktopItemHidden("folder:" .. tostring(item.folderName), true)
                if self.computer then
                    ComputerModComputerTypes.transmitData(self.computer)
                end
                return true
            end
        end
        return false
    end
    if item.kind == "note" then
        local notes = self:getDesktopNotes()
        for i = #notes, 1, -1 do
            if notes[i] and notes[i].key == item.noteKey then
                self:addFolderEntryToTrash({type = "note", key = notes[i].key, label = notes[i].name, text = notes[i].text or ""}, "desktop", nil)
                table.remove(notes, i)
                data.ComputerModDesktopNotes = notes
                self:setDesktopItemHidden("note:" .. tostring(item.noteKey), true)
                if self.computer then
                    ComputerModComputerTypes.transmitData(self.computer)
                end
                if self.syncNotepadDataToServer then
                    self:syncNotepadDataToServer()
                end
                return true
            end
        end
        return false
    end
    if item.kind == "paint" then
        local file = self:getPaintFileByKey(item.paintKey)
        if file then
            self:addFolderEntryToTrash({type = "paint", key = file.key, name = file.name, width = file.width, height = file.height, cells = file.cells}, "desktop", nil)
            return self:deletePaintFileByKey(item.paintKey, true)
        end
        return false
    end
    if item.kind == "stored" and item.entry then
        self:addFolderEntryToTrash(item.entry, "desktop", nil)
        local success = self:removeDesktopStoredFile(item.entry.desktopKey)
        if success and self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        return success
    end
    return false
end

function target:copyDesktopItemToStorage(item, storageName)
    local entry = self:getDesktopFileEntry(item)
    if not entry then return false end
    if self:addEntryToStorage(entry, storageName) then
        self.fileNoticeText = tr("Copied to") .. " " .. self:getStorageDisplayName(storageName) .. "."
        self.fileNoticeTimer = 120
        return true
    end
    return false
end

function target:moveDesktopItemToStorage(item, storageName)
    local entry = self:getDesktopFileEntry(item)
    if not entry then return false end
    if not self:addEntryToStorage(entry, storageName) then return false end
    self:removeDesktopFileEntry(entry)
    self.fileNoticeText = tr("Moved to") .. " " .. self:getStorageDisplayName(storageName) .. "."
    self.fileNoticeTimer = 120
    return true
end

function target:getStorageTargetsForEntry(entry)
    local targets = {}
    if not entry or entry.type == "app" then
        return targets
    end
    local folders = self:getComputerFolders()
    for i = 1, #folders do
        if folders[i] ~= "Downloads" then
            targets[#targets + 1] = {name = folders[i], label = folders[i]}
        end
    end
    if self:isDiscStorageOpenable() and self:isEntryAllowedOnDisc(entry) then
        targets[#targets + 1] = {name = "__CD__", label = "Blank CD (D:)"}
    end
    return targets
end

function target:activateStoredEntry(entry)
    if not entry then return end
    if entry.type == "app" then
        self:activateDesktopItem({kind = "app", app = entry.app, label = entry.label})
        return
    end
    if entry.type == "folder" then
        if entry.name == "__CD__" then
            self:openDiscFolder()
        elseif entry.name == "Downloads" then
            self:openDownloadsFolder()
        else
            self:openFolderView(entry.name)
        end
        return
    end
    if entry.type == "note" then
        if entry.key and not self:getDesktopNoteByKey(entry.key) then
            local data = self:getComputerData()
            local notes = self:getDesktopNotes()
            notes[#notes + 1] = {key = entry.key, name = entry.label or "Note", text = entry.text or ""}
            if data then data.ComputerModDesktopNotes = notes end
        end
        self:openDesktopNote(entry.key)
        return
    end
    if entry.type == "paint" then
        if entry.key and not self:getPaintFileByKey(entry.key) then
            local data = self:getComputerData()
            local files = self:getPaintFiles()
            files[#files + 1] = {key = entry.key, name = entry.label or "Drawing", width = entry.width or 32, height = entry.height or 18, cells = entry.cells or {}}
            if data then data.ComputerModPaintFiles = files end
        end
        self:openPaintFile(entry.key)
        return
    end
    self:readFolderEntry(entry)
end

function target:openDiscFolder()
    if not self:isDiscStorageOpenable() then
        self:showError(tr("This disc cannot be opened here."))
        return
    end
    self:openFolderView("__CD__")
end

function target:backToDesktop()
    self:saveCurrentNote()
    self.currentView = "DESKTOP"
    self.currentFolderName = nil
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self.pongButton:setVisible(false)
    self.snakeButton:setVisible(false)
    self.minesweeperButton:setVisible(false)
    self.tetrisButton:setVisible(false)
    self.spaceInvadersButton:setVisible(false)
    self.doomButton:setVisible(false)
    self.racerButton:setVisible(false)
    if self.flappyButton then self.flappyButton:setVisible(false) end
    if self.breakoutButton then self.breakoutButton:setVisible(false) end
    if self.asteroidsButton then self.asteroidsButton:setVisible(false) end
    if self.froggerButton then self.froggerButton:setVisible(false) end
    if self.missileButton then self.missileButton:setVisible(false) end
    if self.landerButton then self.landerButton:setVisible(false) end
    if self.circuitButton then self.circuitButton:setVisible(false) end
    if self.memoryButton then self.memoryButton:setVisible(false) end
    if self.starPilotButton then self.starPilotButton:setVisible(false) end
    if self.caveRunnerButton then self.caveRunnerButton:setVisible(false) end
    if self.lightsOutButton then self.lightsOutButton:setVisible(false) end
    if self.signalMatchButton then self.signalMatchButton:setVisible(false) end
    if self.boxPushButton then self.boxPushButton:setVisible(false) end
    if self.tileSlideButton then self.tileSlideButton:setVisible(false) end
    if self.pipeLinkButton then self.pipeLinkButton:setVisible(false) end
    if self.codeBreakerButton then self.codeBreakerButton:setVisible(false) end
    if self.outbreakOpsButton then self.outbreakOpsButton:setVisible(false) end
    self.backButton:setVisible(false)
    self:setDesktopShortcutsVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setInstallControlsVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:openGamesMenu()
    self:saveCurrentNote()
    self.currentView = "GAMES"
    self:layoutVisibleGameButtons()
    self.gameContextMenu = nil
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self.fileButton:setVisible(false)
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.gamesMenuButton:setVisible(false)
    self.pongButton:setVisible(self:isGameInstalled("pong"))
    self.snakeButton:setVisible(self:isGameInstalled("snake"))
    self.minesweeperButton:setVisible(self:isGameInstalled("minesweeper"))
    self.tetrisButton:setVisible(self:isGameInstalled("tetris"))
    self.spaceInvadersButton:setVisible(self:isGameInstalled("space_invaders"))
    self.doomButton:setVisible(self:isGameInstalled("doom"))
    self.racerButton:setVisible(self:isGameInstalled("racer"))
    if self.flappyButton then self.flappyButton:setVisible(self:isGameInstalled("flappy")) end
    if self.breakoutButton then self.breakoutButton:setVisible(self:isGameInstalled("breakout")) end
    if self.asteroidsButton then self.asteroidsButton:setVisible(self:isGameInstalled("asteroids")) end
    if self.froggerButton then self.froggerButton:setVisible(self:isGameInstalled("frogger")) end
    if self.missileButton then self.missileButton:setVisible(self:isGameInstalled("missile")) end
    if self.landerButton then self.landerButton:setVisible(self:isGameInstalled("lander")) end
    if self.circuitButton then self.circuitButton:setVisible(self:isGameInstalled("circuit")) end
    if self.memoryButton then self.memoryButton:setVisible(self:isGameInstalled("memory")) end
    if self.starPilotButton then self.starPilotButton:setVisible(self:isGameInstalled("starpilot")) end
    if self.caveRunnerButton then self.caveRunnerButton:setVisible(self:isGameInstalled("caverunner")) end
    if self.lightsOutButton then self.lightsOutButton:setVisible(self:isGameInstalled("lightsout")) end
    if self.signalMatchButton then self.signalMatchButton:setVisible(self:isGameInstalled("signalmatch")) end
    if self.boxPushButton then self.boxPushButton:setVisible(self:isGameInstalled("boxpush")) end
    if self.tileSlideButton then self.tileSlideButton:setVisible(self:isGameInstalled("tileslide")) end
    if self.pipeLinkButton then self.pipeLinkButton:setVisible(self:isGameInstalled("pipelink")) end
    if self.codeBreakerButton then self.codeBreakerButton:setVisible(self:isGameInstalled("codebreaker")) end
    if self.outbreakOpsButton then self.outbreakOpsButton:setVisible(self:isGameInstalled("outbreakops")) end
    self.backButton:setVisible(true)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:moveCloseToWindow()
    local scale = math.max(1, tonumber(self.contentScale or self.uiScale or 1) or 1)
    local function u(value) return math.floor(value * scale + 0.5) end
    local buttonY = self.windowY + u(self.currentView == "GAMES" and 7 or 5)
    self.closeButton:setX(self.windowX + self.windowW - u(20))
    self.closeButton:setY(buttonY)
    self.closeButton:setWidth(u(17))
    self.closeButton:setHeight(u(17))
    self.backButton:setX(self.windowX + self.windowW - u(20))
    self.backButton:setY(buttonY)
    self.backButton:setWidth(u(17))
    self.backButton:setHeight(u(17))
    self.backButton:bringToTop()
    self.closeButton:bringToTop()
    if self.minimizeButton then
        self.minimizeButton:setX(self.windowX + self.windowW - u(38))
        self.minimizeButton:setY(buttonY)
        self.minimizeButton:setWidth(u(16))
        self.minimizeButton:setHeight(u(17))
        self.minimizeButton:bringToTop()
    end
end

function target:restoreMainCloseButton()
    local scale = math.max(1, tonumber(self.contentScale or self.uiScale or 1) or 1)
    local function u(value) return math.floor(value * scale + 0.5) end
    self.closeButton:setX(self.screenX + self.screenWidth - u(25))
    self.closeButton:setY(self.screenY + u(5))
    self.closeButton:setWidth(u(20))
    self.closeButton:setHeight(u(20))
    self.backButton:setX(self.windowX + self.windowW - u(20))
    self.backButton:setY(self.windowY + u(5))
    self.backButton:setWidth(u(17))
    self.backButton:setHeight(u(17))
    if self.minimizeButton then
        self.minimizeButton:setX(self.screenX + self.screenWidth - u(45))
        self.minimizeButton:setY(self.screenY + u(5))
        self.minimizeButton:setWidth(u(18))
        self.minimizeButton:setHeight(u(20))
    end
end

function target:getComputerData()
    if not self.computer then return nil end
    if ComputerModComputerTypes and ComputerModComputerTypes.getData then
        return ComputerModComputerTypes.getData(self.computer)
    end
    return self.computer.getModData and self.computer:getModData() or nil
end

function target:setActiveGamePanelsVisible(visible)
    if self.pongInstance and self.pongInstance.setVisible then self.pongInstance:setVisible(visible) end
    if self.snakeInstance and self.snakeInstance.setVisible then self.snakeInstance:setVisible(visible) end
    if self.minesweeperInstance and self.minesweeperInstance.setVisible then self.minesweeperInstance:setVisible(visible) end
    if self.tetrisInstance and self.tetrisInstance.setVisible then self.tetrisInstance:setVisible(visible) end
    if self.spaceInvadersInstance and self.spaceInvadersInstance.setVisible then self.spaceInvadersInstance:setVisible(visible) end
    if self.doomInstance and self.doomInstance.setVisible then self.doomInstance:setVisible(visible) end
    if self.racerInstance and self.racerInstance.setVisible then self.racerInstance:setVisible(visible) end
    if self.flappyInstance and self.flappyInstance.setVisible then self.flappyInstance:setVisible(visible) end
    if self.breakoutInstance and self.breakoutInstance.setVisible then self.breakoutInstance:setVisible(visible) end
    if self.asteroidsInstance and self.asteroidsInstance.setVisible then self.asteroidsInstance:setVisible(visible) end
    if self.froggerInstance and self.froggerInstance.setVisible then self.froggerInstance:setVisible(visible) end
    if self.missileInstance and self.missileInstance.setVisible then self.missileInstance:setVisible(visible) end
    if self.landerInstance and self.landerInstance.setVisible then self.landerInstance:setVisible(visible) end
    if self.circuitInstance and self.circuitInstance.setVisible then self.circuitInstance:setVisible(visible) end
    if self.memoryInstance and self.memoryInstance.setVisible then self.memoryInstance:setVisible(visible) end
    if self.starPilotInstance and self.starPilotInstance.setVisible then self.starPilotInstance:setVisible(visible) end
    if self.caveRunnerInstance and self.caveRunnerInstance.setVisible then self.caveRunnerInstance:setVisible(visible) end
    if self.lightsOutInstance and self.lightsOutInstance.setVisible then self.lightsOutInstance:setVisible(visible) end
    if self.signalMatchInstance and self.signalMatchInstance.setVisible then self.signalMatchInstance:setVisible(visible) end
    if self.boxPushInstance and self.boxPushInstance.setVisible then self.boxPushInstance:setVisible(visible) end
    if self.tileSlideInstance and self.tileSlideInstance.setVisible then self.tileSlideInstance:setVisible(visible) end
    if self.pipeLinkInstance and self.pipeLinkInstance.setVisible then self.pipeLinkInstance:setVisible(visible) end
    if self.codeBreakerInstance and self.codeBreakerInstance.setVisible then self.codeBreakerInstance:setVisible(visible) end
    if self.outbreakOpsInstance and self.outbreakOpsInstance.setVisible then self.outbreakOpsInstance:setVisible(visible) end
end

function target:setDesktopShortcutsVisible(visible)
    if self.fileButton then self.fileButton:setVisible(false) end
    if self.notepadButton then self.notepadButton:setVisible(false) end
    if self.browserButton then self.browserButton:setVisible(false) end
    if self.calculatorButton then self.calculatorButton:setVisible(false) end
    if self.gamesMenuButton then self.gamesMenuButton:setVisible(false) end
    if self.postsButton then self.postsButton:setVisible(false) end
    if self.settingsDesktopButton then self.settingsDesktopButton:setVisible(false) end
    if self.mailButton then self.mailButton:setVisible(false) end
    if self.musicButton then self.musicButton:setVisible(false) end
    if self.trashButton then self.trashButton:setVisible(false) end
end

function target:hideGameLauncherButtons()
    if self.pongButton then self.pongButton:setVisible(false) end
    if self.snakeButton then self.snakeButton:setVisible(false) end
    if self.minesweeperButton then self.minesweeperButton:setVisible(false) end
    if self.tetrisButton then self.tetrisButton:setVisible(false) end
    if self.spaceInvadersButton then self.spaceInvadersButton:setVisible(false) end
    if self.doomButton then self.doomButton:setVisible(false) end
    if self.racerButton then self.racerButton:setVisible(false) end
    if self.flappyButton then self.flappyButton:setVisible(false) end
    if self.breakoutButton then self.breakoutButton:setVisible(false) end
    if self.asteroidsButton then self.asteroidsButton:setVisible(false) end
    if self.froggerButton then self.froggerButton:setVisible(false) end
    if self.missileButton then self.missileButton:setVisible(false) end
    if self.landerButton then self.landerButton:setVisible(false) end
    if self.circuitButton then self.circuitButton:setVisible(false) end
    if self.memoryButton then self.memoryButton:setVisible(false) end
    if self.starPilotButton then self.starPilotButton:setVisible(false) end
    if self.caveRunnerButton then self.caveRunnerButton:setVisible(false) end
    if self.lightsOutButton then self.lightsOutButton:setVisible(false) end
    if self.signalMatchButton then self.signalMatchButton:setVisible(false) end
    if self.boxPushButton then self.boxPushButton:setVisible(false) end
    if self.tileSlideButton then self.tileSlideButton:setVisible(false) end
    if self.pipeLinkButton then self.pipeLinkButton:setVisible(false) end
    if self.codeBreakerButton then self.codeBreakerButton:setVisible(false) end
    if self.outbreakOpsButton then self.outbreakOpsButton:setVisible(false) end
end

function target:isGameView()
    return self.currentView == "PONG" or self.currentView == "SNAKE" or self.currentView == "MINESWEEPER" or self.currentView == "TETRIS" or self.currentView == "SPACE_INVADERS" or self.currentView == "DOOM" or self.currentView == "RACER" or self.currentView == "FLAPPY" or self.currentView == "BREAKOUT" or self.currentView == "ASTEROIDS" or self.currentView == "FROGGER" or self.currentView == "MISSILE" or self.currentView == "LANDER" or self.currentView == "CIRCUIT" or self.currentView == "MEMORY" or self.currentView == "STARPILOT" or self.currentView == "CAVERUNNER" or self.currentView == "LIGHTSOUT" or self.currentView == "SIGNALMATCH" or self.currentView == "BOXPUSH" or self.currentView == "TILESLIDE" or self.currentView == "PIPELINK" or self.currentView == "CODEBREAKER" or self.currentView == "OUTBREAKOPS"
end

function target:getActiveGameInstance()
    if self.currentView == "PONG" then return self.pongInstance end
    if self.currentView == "SNAKE" then return self.snakeInstance end
    if self.currentView == "MINESWEEPER" then return self.minesweeperInstance end
    if self.currentView == "TETRIS" then return self.tetrisInstance end
    if self.currentView == "SPACE_INVADERS" then return self.spaceInvadersInstance end
    if self.currentView == "DOOM" then return self.doomInstance end
    if self.currentView == "RACER" then return self.racerInstance end
    if self.currentView == "FLAPPY" then return self.flappyInstance end
    if self.currentView == "BREAKOUT" then return self.breakoutInstance end
    if self.currentView == "ASTEROIDS" then return self.asteroidsInstance end
    if self.currentView == "FROGGER" then return self.froggerInstance end
    if self.currentView == "MISSILE" then return self.missileInstance end
    if self.currentView == "LANDER" then return self.landerInstance end
    if self.currentView == "CIRCUIT" then return self.circuitInstance end
    if self.currentView == "MEMORY" then return self.memoryInstance end
    if self.currentView == "STARPILOT" then return self.starPilotInstance end
    if self.currentView == "CAVERUNNER" then return self.caveRunnerInstance end
    if self.currentView == "LIGHTSOUT" then return self.lightsOutInstance end
    if self.currentView == "SIGNALMATCH" then return self.signalMatchInstance end
    if self.currentView == "BOXPUSH" then return self.boxPushInstance end
    if self.currentView == "TILESLIDE" then return self.tileSlideInstance end
    if self.currentView == "PIPELINK" then return self.pipeLinkInstance end
    if self.currentView == "CODEBREAKER" then return self.codeBreakerInstance end
    if self.currentView == "OUTBREAKOPS" then return self.outbreakOpsInstance end
    return nil
end

local function clampComputerMood(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function adjustComputerCharacterStat(stats, stat, delta)
    if not stats or not stat or not delta or delta == 0 then return false end
    if delta < 0 then
        local ok = pcall(function() stats:remove(stat, -delta) end)
        if ok then return true end
    elseif delta > 0 then
        local ok = pcall(function() stats:add(stat, delta) end)
        if ok then return true end
    end
    local okGet, value = pcall(function() return stats:get(stat) end)
    if okGet and type(value) == "number" then
        local okSet = pcall(function() stats:set(stat, math.max(0, value + delta)) end)
        if okSet then return true end
    end
    return false
end

function target:adjustPlayerMood(boredomDelta, stressDelta, sadnessDelta, playerOverride)
    local playerObj = playerOverride or self.playerObj
    if not playerObj and getPlayer then
        local okPlayer, value = pcall(getPlayer)
        if okPlayer then playerObj = value end
    end
    if not playerObj then return end
    local stats = nil
    local bodyDamage = nil
    local okStats, statsValue = pcall(function() return playerObj:getStats() end)
    if okStats then stats = statsValue end
    local okBody, bodyValue = pcall(function() return playerObj:getBodyDamage() end)
    if okBody then bodyDamage = bodyValue end
    if boredomDelta and boredomDelta ~= 0 then
        local changed = CharacterStat and adjustComputerCharacterStat(stats, CharacterStat.BOREDOM, boredomDelta)
        if not changed and bodyDamage then
            local ok, value = pcall(function() return bodyDamage:getBoredomLevel() end)
            if ok and type(value) == "number" then
                pcall(function() bodyDamage:setBoredomLevel(clampComputerMood(value + boredomDelta, 0, 100)) end)
            end
        end
        if not changed and stats then
            local ok, value = pcall(function() return stats:getBoredom() end)
            if ok and type(value) == "number" then
                pcall(function() stats:setBoredom(clampComputerMood(value + boredomDelta, 0, 100)) end)
            end
        end
    end
    if stressDelta and stressDelta ~= 0 then
        local changed = CharacterStat and adjustComputerCharacterStat(stats, CharacterStat.STRESS, stressDelta)
        if not changed and stats then
            local ok, value = pcall(function() return stats:getStress() end)
            if ok and type(value) == "number" then
                pcall(function() stats:setStress(clampComputerMood(value + stressDelta, 0, 1)) end)
            end
        end
    end
    if sadnessDelta and sadnessDelta ~= 0 then
        local changed = CharacterStat and adjustComputerCharacterStat(stats, CharacterStat.UNHAPPINESS, sadnessDelta)
        if not changed and bodyDamage then
            local ok, value = pcall(function() return bodyDamage:getUnhappynessLevel() end)
            if ok and type(value) == "number" then
                pcall(function() bodyDamage:setUnhappynessLevel(clampComputerMood(value + sadnessDelta, 0, 100)) end)
            end
        end
    end
end

function target:updateGameMoodEffects(timeStep)
    if not self:isGameView() then
        self.gameMoodTick = 0
        self.lastGameOutcomeState = nil
        return
    end
    self.gameMoodTick = (self.gameMoodTick or 0) + timeStep
    while self.gameMoodTick >= 30 do
        self.gameMoodTick = self.gameMoodTick - 30
        self:adjustPlayerMood(-0.25, -0.0025, -0.18)
    end
    local game = self:getActiveGameInstance()
    local state = game and game.gameState or nil
    if state == "GAMEOVER" and self.lastGameOutcomeState ~= "GAMEOVER" then
        self:adjustPlayerMood(0, 0.08, 0)
    end
    self.lastGameOutcomeState = state
end

local function updateComputerGameMoodFromPlayer(playerObj)
    local ui = ComputerScreenUI and ComputerScreenUI.instance or nil
    if not ui or not ui.isVisible or not ui:isVisible() then
        if ui then
            ui.gameMoodLastTickMs = nil
            ui.computerUseMoodLastTickMs = nil
            ui.lastPlayerGameOutcomeState = nil
        end
        return
    end
    ui.playerObj = playerObj or ui.playerObj
    local nowMs = getTimestampMs and getTimestampMs() or nil
    if not nowMs then
        return
    end
    ui.computerUseMoodLastTickMs = ui.computerUseMoodLastTickMs or nowMs
    if nowMs - ui.computerUseMoodLastTickMs >= 5000 then
        ui.computerUseMoodLastTickMs = nowMs
        ui:adjustPlayerMood(-0.20, -0.002, -0.15, playerObj)
    end
    if not ui.isGameView or not ui:isGameView() then
        ui.gameMoodLastTickMs = nil
        ui.lastPlayerGameOutcomeState = nil
        return
    end
    ui.gameMoodLastTickMs = ui.gameMoodLastTickMs or nowMs
    if nowMs - ui.gameMoodLastTickMs >= 1000 then
        ui.gameMoodLastTickMs = nowMs
        ui:adjustPlayerMood(-0.35, -0.0035, -0.25, playerObj)
    end
    local game = ui.getActiveGameInstance and ui:getActiveGameInstance() or nil
    local state = game and game.gameState or nil
    if state == "GAMEOVER" and ui.lastPlayerGameOutcomeState ~= "GAMEOVER" then
        ui:adjustPlayerMood(0, 0.08, 0, playerObj)
    end
    ui.lastPlayerGameOutcomeState = state
end

ComputerModGameMoodEventHandler = updateComputerGameMoodFromPlayer

if Events and Events.OnPlayerUpdate and not ComputerModGameMoodEventInstalledV2 then
    ComputerModGameMoodEventInstalledV2 = true
    Events.OnPlayerUpdate.Add(function(playerObj)
        if ComputerModGameMoodEventHandler then
            ComputerModGameMoodEventHandler(playerObj)
        end
    end)
end

function target:canMinimizeCurrentView()
    if self:isFirmwareView() then return false end
    if self.currentView == "DESKTOP" or self.currentView == "BOOTING" or self.currentView == "BOOT_ERROR" then return false end
    if self.currentView == "LOCK" or self.currentView == "PASSWORD" or self.currentView == "PASSWORD_HACK" then return false end
    if self.currentView == "NETWORK_TERMINAL" or self.currentView == "NETWORK_REPAIR" then return false end
    if self.currentView == "RESET_CONFIRM" or self.currentView == "RESETTING" or self.currentView == "DISC_WIPE_CONFIRM" or self.currentView == "DISC_WIPING" then return false end
    return true
end

function target:getMinimizedWindows()
    if type(self.minimizedWindows) ~= "table" then
        self.minimizedWindows = {}
    end
    return self.minimizedWindows
end

function target:isViewMinimized(view)
    local windows = self:getMinimizedWindows()
    for i = 1, #windows do
        if windows[i] and windows[i].view == view then
            return true
        end
    end
    return false
end

function target:removeMinimizedView(view)
    local windows = self:getMinimizedWindows()
    for i = #windows, 1, -1 do
        if windows[i] and windows[i].view == view then
            table.remove(windows, i)
        end
    end
end

function target:getWindowTitleForView(view)
    local titles = {
        FILES = tr("Files"),
        DOWNLOADS = tr("Downlds"),
        FOLDER = tr("Folder"),
        NOTEPAD = tr("Notes"),
        BROWSER = "Browser",
        CALCULATOR = tr("Calc"),
        SETTINGS = tr("Settings"),
        MAIL = "Mail",
        CHAT = "Chat",
        BOARD = "Board",
        MARKET = "Market",
        MUSIC = tr("Music"),
        TRASH = tr("Trash"),
        GAMES = tr("Games"),
        PONG = "Pong",
        SNAKE = "Snake",
        MINESWEEPER = "Mines",
        TETRIS = "Tetris",
        SPACE_INVADERS = "Invaders",
        DOOM = "Doom",
        RACER = "Road",
        FLAPPY = "Flappy",
        BREAKOUT = "Breakout",
        ASTEROIDS = "Asteroids",
        FROGGER = "Frogger",
        MISSILE = "Missile",
        LANDER = "Lander",
        CIRCUIT = "Circuit",
        MEMORY = "Memory",
        STARPILOT = "Star Pilot",
        CAVERUNNER = "Cave",
        LIGHTSOUT = "Lights",
        SIGNALMATCH = "Signal",
        BOXPUSH = "Box Push",
        TILESLIDE = "Tile",
        PIPELINK = "Pipe",
        CODEBREAKER = "Code",
        OUTBREAKOPS = "Outbreak",
        PAINT = "Paint",
        INSTALLER = tr("Setup"),
        INSTALLING = tr("Setup")
    }
    return titles[view] or tr("Window")
end

function target:getMinimizedTaskbarSlot(index)
    local windows = self:getMinimizedWindows()
    if not windows[index] then return nil end
    local scale = tonumber(self.contentScale or self.uiScale or 1) or 1
    local taskbarY = self.screenY + self.screenHeight - 25
    local startX = self.screenX + math.floor(70 * scale + 0.5)
    local slotW = math.floor(84 * scale + 0.5)
    local gap = math.floor(6 * scale + 0.5)
    return {x = startX + ((index - 1) * (slotW + gap)), y = taskbarY + 2, w = slotW, h = math.floor(21 * scale + 0.5)}
end

function target:getComputerRoomName()
    if not self.computer or not self.computer.getSquare then return "" end
    local square = self.computer:getSquare()
    if not square then return "" end
    local room = square.getRoom and square:getRoom() or nil
    if room and room.getName then
        return string.lower(tostring(room:getName() or ""))
    end
    return ""
end

function target:generateComputerID()
    if not self.computer then return tostring(ZombRand(999999)) end
    local x = math.floor(self.computer:getX() or 0)
    local y = math.floor(self.computer:getY() or 0)
    local z = math.floor(self.computer:getZ() or 0)
    return string.format("PC-%d-%d-%d-%03d", x, y, z, ZombRand(1000))
end

function target:generateComputerPassword()
    if ComputerModPasswordNotes and ComputerModPasswordNotes.randomPassword then
        return ComputerModPasswordNotes.randomPassword()
    end
    return easyComputerPasswords[ZombRand(#easyComputerPasswords) + 1]
end

function target:generateRoomFolders()
    local roomName = self:getComputerRoomName()
    local pool = {"Notes", "Archive", "Drafts", "Logs"}
    if string.find(roomName, "class") or string.find(roomName, "school") or string.find(roomName, "library") then
        pool = {"Student Notes", "Attendance", "Lesson Plans", "Exams"}
    elseif string.find(roomName, "police") or string.find(roomName, "security") or string.find(roomName, "jail") then
        pool = {"Case Files", "Suspects", "Evidence", "Incident Logs"}
    elseif string.find(roomName, "medical") or string.find(roomName, "hospital") or string.find(roomName, "clinic") then
        pool = {"Patients", "Prescriptions", "Shift Notes", "Lab Results"}
    elseif string.find(roomName, "office") or string.find(roomName, "meeting") then
        pool = {"Reports", "Payroll", "Schedules", "Drafts"}
    elseif string.find(roomName, "kitchen") or string.find(roomName, "restaurant") or string.find(roomName, "cafe") then
        pool = {"Orders", "Inventory", "Suppliers", "Receipts"}
    elseif string.find(roomName, "store") or string.find(roomName, "market") then
        pool = {"Stock", "Invoices", "Suppliers", "Receipts"}
    elseif string.find(roomName, "bedroom") or string.find(roomName, "living") or string.find(roomName, "bathroom") then
        pool = {"Bills", "Letters", "Photos", "Recipes"}
    end

    local folders = {}
    if ZombRand(100) < ComputerModSandbox.getPercent("EmptyFolderChance") then
        return folders
    end

    local count = 2 + ZombRand(3)
    while #folders < count and #folders < #pool do
        local candidate = pool[ZombRand(#pool) + 1]
        local exists = false
        for i = 1, #folders do
            if folders[i] == candidate then
                exists = true
                break
            end
        end
        if not exists then
            folders[#folders + 1] = candidate
        end
    end
    return folders
end

function target:generateRoomNoteText()
    local roomName = self:getComputerRoomName()
    local pool = {
        {
            "Reminder:",
            "- Check backup disks",
            "- Call supplier before Friday",
            "- Clean keyboard",
            "",
            "Leave monitor off overnight."
        },
        {
            "Quick notes:",
            "Front desk called twice.",
            "Printer jam on tray 2.",
            "Need fresh floppies.",
            "",
            "Do not forget the spare keys."
        },
        {
            "Desk pad:",
            "Move invoices to the blue folder.",
            "Run disk cleanup before closing.",
            "",
            "The modem line clicks after rain."
        },
        {
            "Loose note:",
            "- Label the blank CDs",
            "- Copy the address book",
            "- Bring spare batteries",
            "",
            "Someone keeps changing the wallpaper."
        }
    }
    if string.find(roomName, "class") or string.find(roomName, "school") or string.find(roomName, "library") then
        pool = {
            {
                "Lesson notes:",
                "- Review chapter 4",
                "- Print quiz sheets",
                "- Move projector cart",
                "",
                "Collect homework before lunch."
            },
            {
                "School memo:",
                "Attendance forms due Thursday.",
                "Science lab needs new glassware.",
                "",
                "Keep hall passes near the office."
            },
            {
                "Library desk:",
                "Return cards are piling up.",
                "Replace the ribbon in the catalog printer.",
                "",
                "Ask Mr. Wilson about the missing study guide."
            },
            {
                "Teacher notes:",
                "- Mark geography quizzes",
                "- Unlock AV cart",
                "- Save lesson files to disk",
                "",
                "Do not let students use the office computer."
            }
        }
    elseif string.find(roomName, "police") or string.find(roomName, "security") or string.find(roomName, "jail") then
        pool = {
            {
                "Desk note:",
                "Night shift logged two incidents.",
                "Locker 3 still needs a new tag.",
                "",
                "Do not move the evidence boxes."
            },
            {
                "Case board update:",
                "- Interview rescheduled",
                "- Vehicle report copied",
                "- Archive old witness tape",
                "",
                "Ask dispatch for the missing file."
            },
            {
                "Dispatch note:",
                "Radio desk logged static after 23:00.",
                "Evidence locker needs a second signature.",
                "",
                "Copy shift roster before the captain asks."
            },
            {
                "Report draft:",
                "- South door alarm false",
                "- Cruiser keys moved",
                "- Photo envelope sealed",
                "",
                "Do not file this until numbers match."
            }
        }
    elseif string.find(roomName, "medical") or string.find(roomName, "hospital") or string.find(roomName, "clinic") then
        pool = {
            {
                "Shift notes:",
                "Restock bandages in cabinet B.",
                "Phone the lab after 14:00.",
                "",
                "Cold room thermostat is drifting again."
            },
            {
                "Clinic reminder:",
                "- Update patient forms",
                "- Check generator fuel",
                "- Lock sample fridge",
                "",
                "Morning rounds start early tomorrow."
            },
            {
                "Nurse station:",
                "Exam room two needs fresh sheets.",
                "Call pharmacy about late crate.",
                "",
                "Keep the records cabinet closed."
            },
            {
                "Lab memo:",
                "- Label blood trays",
                "- Replace gloves box",
                "- Print supply form",
                "",
                "The old printer skips every third line."
            }
        }
    elseif string.find(roomName, "office") or string.find(roomName, "meeting") then
        pool = {
            {
                "Office list:",
                "Payroll packet still unsigned.",
                "Call West Point branch.",
                "",
                "Bring quarterly reports upstairs."
            },
            {
                "Meeting follow-up:",
                "- Copy budget figures",
                "- Mail contract draft",
                "- Replace conference bulbs",
                "",
                "Coffee budget is already gone."
            },
            {
                "Branch memo:",
                "Fax line worked after two tries.",
                "Move staff birthdays off the shared calendar.",
                "",
                "Do not trust the numbers in Q2_old.xls."
            },
            {
                "Reception note:",
                "- Call courier",
                "- Refill copier tray",
                "- Archive visitor sheets",
                "",
                "The boss wants the beige monitor back."
            }
        }
    elseif string.find(roomName, "kitchen") or string.find(roomName, "restaurant") or string.find(roomName, "cafe") then
        pool = {
            {
                "Kitchen board:",
                "Order more cooking oil.",
                "Freezer seal still looks weak.",
                "",
                "Move canned goods before inspection."
            },
            {
                "Prep notes:",
                "- Slice tomatoes first",
                "- Count clean trays",
                "- Call bread supplier",
                "",
                "Evening rush was heavier yesterday."
            },
            {
                "Line cook note:",
                "Soup cans go under the prep table.",
                "Coffee filters are in the dry shelf.",
                "",
                "Hide the good spatula from night shift."
            },
            {
                "Order pad:",
                "- Flour",
                "- Sugar",
                "- Two boxes of fryer gloves",
                "",
                "The pie recipe disk is not a coaster."
            }
        }
    elseif string.find(roomName, "store") or string.find(roomName, "market") then
        pool = {
            {
                "Store list:",
                "Price gun is missing again.",
                "Move canned soup to front aisle.",
                "",
                "Check the back stock after lunch."
            },
            {
                "Delivery memo:",
                "- Crackers came in short",
                "- Soap shipment delayed",
                "",
                "Ask Rosewood branch about spare shelves."
            },
            {
                "Manager note:",
                "Endcap signs are wrong again.",
                "Count batteries near register two.",
                "",
                "Receipt printer eats paper when rushed."
            },
            {
                "Stock room:",
                "- Check cereal dates",
                "- Move bleach higher",
                "- Tag dented cans",
                "",
                "Leave the loading door latched."
            }
        }
    elseif string.find(roomName, "bedroom") or string.find(roomName, "living") or string.find(roomName, "bathroom") then
        pool = {
            {
                "Home notes:",
                "Pay the electric bill.",
                "Call aunt June on Sunday.",
                "",
                "Tape the recipe to the fridge later."
            },
            {
                "Things to do:",
                "- Wash blankets",
                "- Buy batteries",
                "- Sort old letters",
                "",
                "Do not forget the spare house key."
            },
            {
                "Fridge note:",
                "Call mom after dinner.",
                "Return movies before late fee.",
                "",
                "The upstairs light flickers again."
            },
            {
                "Personal list:",
                "- Fix cassette deck",
                "- Find tax envelope",
                "- Copy recipes for Tina",
                "",
                "No more coffee after midnight."
            }
        }
    end
    local lines = pool[ZombRand(#pool) + 1]
    if ComputerModSecretSiteHints and #ComputerModSecretSiteHints > 0 and ZombRand(100) < ComputerModSandbox.getPercent("SecretSiteHintChance") then
        local hintSite = ComputerModSecretSiteHints[ZombRand(#ComputerModSecretSiteHints) + 1]
        local naturalHints = {
            "Ray said the missing scans were posted on " .. hintSite .. " after closing.",
            "If the printed issue is gone, check " .. hintSite .. " from the office machine.",
            "Someone copied the workshop notes to " .. hintSite .. "; do not leave it on the board.",
            "I wrote down " .. hintSite .. " in case the magazine box goes missing again."
        }
        lines[#lines + 1] = ""
        lines[#lines + 1] = naturalHints[ZombRand(#naturalHints) + 1]
    end
    return table.concat(lines, "\n")
end

function target:generateCalculatorHistoryDisplay()
    local values = {"17", "24", "36", "48", "64", "72", "90", "120", "144", "225", "360", "512", "728", "1024"}
    return values[ZombRand(#values) + 1]
end

function target:generateInstalledGames()
    local installed = {}
    if ZombRand(100) >= ComputerModSandbox.getPercent("PreinstalledGameChance") then
        return installed
    end
    local roll = ZombRand(100)
    local targetCount = 1
    if roll >= 58 and roll < 92 then
        targetCount = 2
    elseif roll >= 92 then
        targetCount = 3
    else
        targetCount = 1
    end
    while #installed < targetCount do
        local candidate = gameInstallOrder[ZombRand(#gameInstallOrder) + 1]
        local exists = false
        for i = 1, #installed do
            if installed[i] == candidate then
                exists = true
                break
            end
        end
        if not exists then
            installed[#installed + 1] = candidate
        end
    end
    return installed
end

function target:getMountedDiscGame()
    local data = self:getComputerData()
    if not data then return nil end
    local discGame = data.ComputerModMountedCD
    if discGame and gameInstallInfo[discGame] then
        return discGame
    end
    local mountedType = data.ComputerModMountedCDItem or discGame
    local normalizedType = mountedType and string.lower(tostring(mountedType)) or ""
    if normalizedType ~= "" then
        for gameId, fullType in pairs(gameDiscItems) do
            if string.lower(tostring(fullType)) == normalizedType then
                return gameId
            end
        end
    end
    return nil
end

function target:getMountedDiscInfo()
    local data = self:getComputerData()
    if not data then return nil end
    local mountedValue = data.ComputerModMountedCD
    if not mountedValue then return nil end
    local discGame = self:getMountedDiscGame()
    local info = gameInstallInfo[discGame]
    if info then
        local result = {}
        for k, v in pairs(info) do
            result[k] = v
        end
        if data.ComputerModMountedCDLabel and data.ComputerModMountedCDLabel ~= "" then
            result.disc = data.ComputerModMountedCDLabel
            result.label = data.ComputerModMountedCDLabel
        end
        result.gameId = discGame
        result.itemType = data.ComputerModMountedCDItem
        return result
    end
    return {
        gameId = "generic",
        label = data.ComputerModMountedCDLabel or "Data CD",
        disc = data.ComputerModMountedCDLabel or "Data CD",
        texture = nil,
        generic = true,
        discSizeMB = 650,
        itemType = data.ComputerModMountedCDItem
    }
end

function target:isHackDiscMounted()
    local data = self:getComputerData()
    if not data then return false end
    if data.ComputerModMountedCD == "hack" then return true end
    return data.ComputerModMountedCDItem == "ComputerMod.PasswordHackCD"
end

function target:getPasswordHackLockRemaining()
    local data = self:getComputerData()
    if not data then return 0 end
    local lockUntil = tonumber(data.ComputerModHackLockUntil or 0) or 0
    if lockUntil <= 0 then return 0 end
    local remaining = lockUntil - getComputerWorldAgeHours()
    if remaining <= 0 then
        data.ComputerModHackLockUntil = nil
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        return 0
    end
    return remaining
end

function target:getHackRequiredElectricalLevel()
    local value = 1
    if ComputerModSandbox and ComputerModSandbox.getNumber then
        value = ComputerModSandbox.getNumber("HackRequiredElectricalLevel", (ComputerModSandbox.defaults and ComputerModSandbox.defaults.HackRequiredElectricalLevel) or 1)
    end
    value = tonumber(value or 0) or 0
    if value < 0 then value = 0 end
    if value > 10 then value = 10 end
    return value
end

function target:getElectricalSkillLevel()
    local player = self.playerObj or (getPlayer and getPlayer()) or nil
    if not player or not player.getPerkLevel then return 0 end
    local perk = nil
    if Perks then
        perk = Perks.Electricity
        if not perk and Perks.FromString then
            local okPerk, perkValue = pcall(function() return Perks.FromString("Electricity") end)
            if okPerk then perk = perkValue end
        end
    end
    if not perk then return 0 end
    local okLevel, level = pcall(function() return player:getPerkLevel(perk) end)
    if okLevel and tonumber(level) then
        return tonumber(level)
    end
    return 0
end

function target:canShowHackButton()
    return self.currentView == "LOCK"
        and self:hasPassword()
        and self:isHackDiscMounted()
        and self:getPasswordHackLockRemaining() <= 0
        and self:getElectricalSkillLevel() >= self:getHackRequiredElectricalLevel()
end

function target:isValidMagazineType(fullType)
    if not fullType or not ComputerModMagazineData or not ComputerModMagazineData[fullType] then
        return false
    end
    if getScriptManager and getScriptManager() and getScriptManager().FindItem then
        local ok, item = pcall(function() return getScriptManager():FindItem(fullType) end)
        if ok then
            return item ~= nil
        end
    end
    return true
end

function target:filterMagazineList(list)
    local filtered = {}
    if type(list) ~= "table" then return filtered end
    for i = 1, #list do
        if self:isValidMagazineType(list[i]) then
            filtered[#filtered + 1] = list[i]
        end
    end
    return filtered
end

function target:getMagazineDisplayName(fullType)
    local data = ComputerModMagazineData and ComputerModMagazineData[fullType] or nil
    if InventoryItemFactory and InventoryItemFactory.CreateItem then
        local ok, item = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
        if ok and item and item.getDisplayName then
            local okName, displayName = pcall(function() return item:getDisplayName() end)
            if okName and displayName and tostring(displayName) ~= "" then return tostring(displayName) end
        end
    end
    if data and data.label and ComputerModLocalization then
        return ComputerModLocalization.text("Magazine", fullType, "Label", data.label)
    end
    local name = tostring(fullType or "Magazine")
    name = string.gsub(name, "^Base%.", "")
    name = string.gsub(name, "Mag", " Mag ")
    name = string.gsub(name, "(%l)(%u)", "%1 %2")
    name = string.gsub(name, "(%a)(%d)", "%1 %2")
    name = string.gsub(name, "%s+", " ")
    return name
end

function target:getMagazineIconTexture(fullType)
    local data = ComputerModMagazineData and ComputerModMagazineData[fullType] or nil
    if not getTexture then return nil end
    if not data or not data.icon then
        return getTexture("media/textures/cd.png")
    end
    return getTexture("Item_" .. tostring(data.icon)) or getTexture("media/textures/cd.png")
end

function target:isValidNewspaperId(id)
    return id ~= nil and ComputerModNewspaperData ~= nil and ComputerModNewspaperData[id] ~= nil
end

function target:getNewspaperDisplayName(id)
    local data = ComputerModNewspaperData and ComputerModNewspaperData[id] or nil
    local fallback = data and data.label or "Newspaper"
    return ComputerModLocalization and ComputerModLocalization.text("Newspaper", id, "Label", fallback) or fallback
end

function target:getNewspaperIconTexture(id)
    if not getTexture then return nil end
    local data = ComputerModNewspaperData and ComputerModNewspaperData[id] or nil
    local icon = data and data.icon or "Newspaper"
    local candidates = {
        "Item_" .. tostring(icon),
        tostring(icon),
        "Item_Newspaper",
        "Item_PaperReport1",
        "media/textures/Note.PNG"
    }
    for i = 1, #candidates do
        local tex = getTexture(candidates[i])
        if tex then
            return tex
        end
    end
    return getTexture("media/textures/Note.PNG")
end

function target:getReadableEntryDisplayName(entry)
    if not entry then
        return "Document"
    end
    if entry.type == "app" then
        return entry.label or appEntryLabels[entry.app] or "Application"
    end
    if entry.type == "folder" then
        return entry.label or entry.name or "Folder"
    end
    if entry.type == "note" then
        return entry.label or "Note"
    end
    if entry.type == "paint" then
        return entry.label or "Drawing"
    end
    if entry.type == "video" then
        return self:getVideoDisplayName(entry.id)
    end
    if entry.type == "newspaper" then
        return self:getNewspaperDisplayName(entry.id)
    end
    return self:getMagazineDisplayName(entry.id)
end

function target:getReadableEntryIconTexture(entry)
    if not entry then
        return getTexture("media/textures/Note.PNG")
    end
    if entry.type == "app" then
        local appTextures = {
            files = desktopFilesTexture,
            notepad = desktopNoteTexture,
            browser = desktopBrowserTexture,
            calculator = desktopCalculatorTexture,
            games = desktopFolderTexture,
            board = getTexture and getTexture("media/textures/board.png") or nil,
            trash = desktopTrashTexture,
            music = desktopMusicTexture,
            mail = desktopMailTexture,
            chat = getTexture and getTexture("media/textures/chat.PNG") or nil,
            settings = desktopSettingsTexture,
            paint = desktopPaintTexture
        }
        return appTextures[entry.app] or desktopFilesTexture
    end
    if entry.type == "folder" then
        return desktopFolderTexture
    end
    if entry.type == "note" then
        return desktopNoteTexture
    end
    if entry.type == "paint" then
        return desktopPaintTexture
    end
    if entry.type == "video" then
        return self:getVideoIconTexture(entry.id)
    end
    if entry.type == "newspaper" then
        return self:getNewspaperIconTexture(entry.id)
    end
    return self:getMagazineIconTexture(entry.id)
end

function target:isValidVideoId(id)
    return id ~= nil and ComputerModVideoData ~= nil and ComputerModVideoData[id] ~= nil
end

function target:getVideoDisplayName(id)
    local data = ComputerModVideoData and ComputerModVideoData[id] or nil
    local fallback = data and data.label or "VHS Tape"
    return ComputerModLocalization and ComputerModLocalization.text("Video", id, "Label", fallback) or fallback
end

function target:getVideoIconTexture(id)
    if not getTexture then return nil end
    local data = ComputerModVideoData and ComputerModVideoData[id] or nil
    local icon = data and data.icon or "VHS"
    local candidates = {
        "Item_" .. tostring(icon),
        tostring(icon),
        "Item_VHS",
        "media/textures/cd.png"
    }
    for i = 1, #candidates do
        local tex = getTexture(candidates[i])
        if tex then
            return tex
        end
    end
    return getTexture("media/textures/cd.png")
end

function target:getTrashEntries()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModTrashEntries) ~= "table" then data.ComputerModTrashEntries = {} end
    return data.ComputerModTrashEntries
end

function target:getDownloadedMagazines()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModDownloadedMagazines) ~= "table" then data.ComputerModDownloadedMagazines = {} end
    local filtered = {}
    for i = 1, #data.ComputerModDownloadedMagazines do
        local entry = data.ComputerModDownloadedMagazines[i]
        if entry and entry.id and self:isValidMagazineType(entry.id) then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "video" and entry.id and self:isValidVideoId(entry.id) then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "newspaper" and entry.id and self:isValidNewspaperId(entry.id) then
            filtered[#filtered + 1] = entry
        end
    end
    data.ComputerModDownloadedMagazines = filtered
    return data.ComputerModDownloadedMagazines
end

function target:isVideoDownloaded(videoId)
    if not videoId or not self:isValidVideoId(videoId) then return false end
    local downloads = self:getDownloadedMagazines()
    for i = 1, #downloads do
        local entry = downloads[i]
        if entry and entry.type == "video" and entry.id == videoId then
            return true
        end
    end
    return false
end

function target:getRoomMagazinePool()
    local roomName = ""
    if self.getComputerRoomName then
        roomName = tostring(self:getComputerRoomName() or "")
    end
    local pool = {}
    local function addPrefix(prefix)
        for fullType, _ in pairs(ComputerModMagazineData or {}) do
            if self:isValidMagazineType(fullType) and string.find(fullType, prefix, 1, true) then
                pool[#pool + 1] = fullType
            end
        end
    end
    if string.find(roomName, "police") or string.find(roomName, "security") or string.find(roomName, "jail") then
        addPrefix("Base.WeaponMag")
        addPrefix("Base.ArmorMag")
        addPrefix("Base.ElectronicsMag")
    elseif string.find(roomName, "medical") or string.find(roomName, "hospital") or string.find(roomName, "clinic") then
        addPrefix("Base.HerbalistMag")
        addPrefix("Base.FarmingMag")
        addPrefix("Base.CookingMag")
    elseif string.find(roomName, "class") or string.find(roomName, "school") or string.find(roomName, "library") then
        addPrefix("Base.CookingMag")
        addPrefix("Base.MechanicMag")
        addPrefix("Base.ElectronicsMag")
        addPrefix("Base.KnittingMag")
    elseif string.find(roomName, "kitchen") or string.find(roomName, "restaurant") or string.find(roomName, "cafe") or string.find(roomName, "store") or string.find(roomName, "market") then
        addPrefix("Base.CookingMag")
        addPrefix("Base.FarmingMag")
        addPrefix("Base.FishingMag")
    else
        addPrefix("Base.MechanicMag")
        addPrefix("Base.ElectronicsMag")
        addPrefix("Base.CookingMag")
        addPrefix("Base.FarmingMag")
        addPrefix("Base.HuntingMag")
    end
    if #pool == 0 then
        for fullType, _ in pairs(ComputerModMagazineData or {}) do
            if self:isValidMagazineType(fullType) then
                pool[#pool + 1] = fullType
            end
        end
    end
    return pool
end

function target:getRoomNewspaperPool()
    local roomName = ""
    if self.getComputerRoomName then
        roomName = string.lower(tostring(self:getComputerRoomName() or ""))
    end
    local pool = {}
    for id, info in pairs(ComputerModNewspaperData or {}) do
        local matched = false
        if info and type(info.tags) == "table" then
            for i = 1, #info.tags do
                local tag = string.lower(tostring(info.tags[i] or ""))
                if tag == "generic" or string.find(roomName, tag, 1, true) then
                    matched = true
                    break
                end
            end
        end
        if matched then
            pool[#pool + 1] = id
        end
    end
    if #pool == 0 then
        for id, _ in pairs(ComputerModNewspaperData or {}) do
            pool[#pool + 1] = id
        end
    end
    return pool
end

function target:getRoomVideoPool()
    local roomName = ""
    if self.getComputerRoomName then
        roomName = string.lower(tostring(self:getComputerRoomName() or ""))
    end
    local pool = {}
    for id, info in pairs(ComputerModVideoData or {}) do
        local matched = false
        if info and type(info.tags) == "table" then
            for i = 1, #info.tags do
                local tag = string.lower(tostring(info.tags[i] or ""))
                if tag == "generic" or string.find(roomName, tag, 1, true) then
                    matched = true
                    break
                end
            end
        end
        if matched then
            pool[#pool + 1] = id
        end
    end
    if #pool == 0 then
        for id, _ in pairs(ComputerModVideoData or {}) do
            pool[#pool + 1] = id
        end
    end
    return pool
end

function target:generateFolderItems(folderName)
    local entries = {}
    local pool = self:getRoomMagazinePool()
    local newspaperPool = self:getRoomNewspaperPool()
    local videoPool = self:getRoomVideoPool()
    local tries = 0
    local desired = 0
    if ZombRand(100) < ComputerModSandbox.getPercent("FolderMagazineChance") then
        desired = 1
        if ZombRand(100) < 6 then
            desired = 2
        end
    end
    while #entries < desired and tries < 60 and #pool > 0 do
        tries = tries + 1
        local fullType = pool[ZombRand(#pool) + 1]
        local exists = false
        for i = 1, #entries do
            if entries[i].type == "magazine" and entries[i].id == fullType then
                exists = true
                break
            end
        end
        if not exists then
            entries[#entries + 1] = {type = "magazine", id = fullType}
        end
    end
    tries = 0
    desired = 0
    if ZombRand(100) < ComputerModSandbox.getPercent("FolderNewspaperChance") then
        desired = 1
        if ZombRand(100) < 12 then
            desired = 2
        end
    end
    while desired > 0 and tries < 60 and #newspaperPool > 0 do
        tries = tries + 1
        local paperId = newspaperPool[ZombRand(#newspaperPool) + 1]
        local exists = false
        for i = 1, #entries do
            if entries[i].type == "newspaper" and entries[i].id == paperId then
                exists = true
                break
            end
        end
        if not exists then
            entries[#entries + 1] = {type = "newspaper", id = paperId}
            desired = desired - 1
        end
    end
    tries = 0
    desired = 0
    if ZombRand(100) < ComputerModSandbox.getPercent("FolderVideoChance") then
        desired = 1
    end
    while desired > 0 and tries < 40 and #videoPool > 0 do
        tries = tries + 1
        local videoId = videoPool[ZombRand(#videoPool) + 1]
        local exists = false
        for i = 1, #entries do
            if entries[i].type == "video" and entries[i].id == videoId then
                exists = true
                break
            end
        end
        if not exists then
            entries[#entries + 1] = {type = "video", id = videoId}
            desired = desired - 1
        end
    end
    return entries
end

function target:ensureFolderData()
    local data = self:getComputerData()
    if not data then return end
    if type(data.ComputerModFolders) ~= "table" then data.ComputerModFolders = {} end
    if type(data.ComputerModFolderContents) ~= "table" then data.ComputerModFolderContents = {} end
    data.ComputerModUserFolders = data.ComputerModUserFolders or {}
    local rerollFolderContents = data.ComputerModFolderContentVersion ~= 4
    for i = 1, #data.ComputerModFolders do
        local name = data.ComputerModFolders[i]
        if name ~= "Downloads" and not data.ComputerModUserFolders[name] then
            if rerollFolderContents then
                data.ComputerModFolderContents[name] = self:generateFolderItems(name)
            elseif data.ComputerModFolderContents[name] == nil then
                data.ComputerModFolderContents[name] = self:generateFolderItems(name)
            end
        end
    end
    if rerollFolderContents then
        data.ComputerModFolderContentVersion = 4
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
end

function target:getFolderContents(folderName)
    self:ensureFolderData()
    local data = self:getComputerData()
    if not data then return {} end
    folderName = tostring(folderName or "")
    if folderName == "__CD__" then
        if not self:isDiscStorageOpenable() then return {} end
        return self:getMountedDiscContents()
    end
    if type(data.ComputerModFolderContents) ~= "table" then data.ComputerModFolderContents = {} end
    data.ComputerModFolderContents[folderName] = data.ComputerModFolderContents[folderName] or {}
    local filtered = {}
    for i = 1, #data.ComputerModFolderContents[folderName] do
        local entry = data.ComputerModFolderContents[folderName][i]
        if entry and entry.type == "magazine" and entry.id and self:isValidMagazineType(entry.id) then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "newspaper" and entry.id and self:isValidNewspaperId(entry.id) then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "video" and entry.id and self:isValidVideoId(entry.id) then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "folder" and entry.name then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "note" and entry.key then
            filtered[#filtered + 1] = entry
        elseif entry and entry.type == "paint" and entry.key then
            filtered[#filtered + 1] = entry
        end
    end
    data.ComputerModFolderContents[folderName] = filtered
    return data.ComputerModFolderContents[folderName]
end

function target:addFolderToTrash(name, source, folderName)
    local data = self:getComputerData()
    if not data or not name or name == "" then return end
    local trash = self:getTrashEntries()
    local items = {}
    local sourceItems = self:getFolderContents(name)
    for i = 1, #sourceItems do
        items[#items + 1] = cloneComputerEntry(sourceItems[i])
    end
    trash[#trash + 1] = {type = "folder", name = name, items = items, source = source or "desktop", folderName = folderName, userCreated = data.ComputerModUserFolders and data.ComputerModUserFolders[name] == true}
    data.ComputerModTrashEntries = trash
end

function target:addFolderEntryToTrash(entry, source, folderName)
    local data = self:getComputerData()
    if not data or not entry then return end
    local trash = self:getTrashEntries()
    local removed = cloneComputerEntry(entry)
    removed.source = source
    removed.folderName = folderName
    trash[#trash + 1] = removed
    data.ComputerModTrashEntries = trash
end

function target:addMagazineToTrash(entry)
    self:addFolderEntryToTrash(entry, "downloads", nil)
end

function target:addDownloadedMagazine(fullType)
    if not self:isValidMagazineType(fullType) then
        return false
    end
    local downloads = self:getDownloadedMagazines()
    for i = 1, #downloads do
        if downloads[i].id == fullType then
            return false
        end
    end
    downloads[#downloads + 1] = {type = "magazine", id = fullType}
    local data = self:getComputerData()
    if data then
        data.ComputerModDownloadedMagazines = downloads
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    return true
end

function target:addDownloadedVideo(videoId)
    if not self:isValidVideoId(videoId) then
        return false
    end
    local downloads = self:getDownloadedMagazines()
    for i = 1, #downloads do
        if downloads[i].type == "video" and downloads[i].id == videoId then
            return false
        end
    end
    downloads[#downloads + 1] = {type = "video", id = videoId}
    local data = self:getComputerData()
    if data then
        data.ComputerModDownloadedMagazines = downloads
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    return true
end

function target:completeMagazineRead(entry)
    if not entry or entry.type ~= "magazine" or not self.playerObj or not self:isValidMagazineType(entry.id) then return end
    local info = ComputerModMagazineData and ComputerModMagazineData[entry.id] or nil
    if isClient and isClient() and sendClientCommand then
        local square = self.computer and self.computer.getSquare and self.computer:getSquare() or nil
        local data = self:getComputerData()
        if not square then
            self:showError(tr("The requested operation could not be completed."))
            return
        end
        sendClientCommand(self.playerObj, "ComputerModComputerData", "MarkMagazineRead", {
            fullType = entry.id,
            x = square:getX(),
            y = square:getY(),
            z = square:getZ(),
            machineId = data and tostring(data.ComputerModMachineID or "") or "",
            computerType = data and tostring(data.ComputerModComputerType or "desktop") or "desktop"
        })
    else
        local pages = 0
        if info and type(info.recipes) == "table" then
            for i = 1, #info.recipes do
                local recipe = info.recipes[i]
                if recipe and self.playerObj.learnRecipe then
                    pcall(function() self.playerObj:learnRecipe(recipe) end)
                end
                if recipe and self.playerObj.getKnownRecipes then
                    pcall(function() self.playerObj:getKnownRecipes():add(recipe) end)
                end
            end
        end
        if InventoryItemFactory then
            local ok, item = pcall(function() return InventoryItemFactory.CreateItem(entry.id) end)
            if ok and item then
                if item.getNumberOfPages then
                    local okPages, value = pcall(function() return item:getNumberOfPages() end)
                    if okPages then pages = tonumber(value or 0) or 0 end
                end
                if item.setAlreadyReadPages and item.getNumberOfPages then
                    pcall(function() item:setAlreadyReadPages(item:getNumberOfPages()) end)
                end
                if pages > 0 and self.playerObj.setAlreadyReadPages then
                    pcall(function() self.playerObj:setAlreadyReadPages(entry.id, pages) end)
                end
                if self.playerObj.getAlreadyReadBook then
                    pcall(function() self.playerObj:getAlreadyReadBook():add(entry.id) end)
                end
                if self.playerObj.ReadLiterature and (not instanceof or instanceof(item, "Literature")) then
                    pcall(function() self.playerObj:ReadLiterature(item) end)
                end
            end
        end
        if sendSyncPlayerFields then
            pcall(function() sendSyncPlayerFields(self.playerObj, 0x00000007) end)
        end
    end
    self.fileNoticeText = tr("Learned from") .. " " .. self:getMagazineDisplayName(entry.id) .. "."
    self.fileNoticeTimer = 150
end

function target:completeNewspaperRead(entry)
    if not entry or entry.type ~= "newspaper" or not self.playerObj or not self:isValidNewspaperId(entry.id) then return end
    self:adjustPlayerMood(-10, -0.04, -8, self.playerObj)
    self.fileNoticeText = tr("Finished reading") .. " " .. self:getNewspaperDisplayName(entry.id) .. "."
    self.fileNoticeTimer = 150
end

function target:completeVideoRead(entry)
    if not entry or entry.type ~= "video" or not self.playerObj or not self:isValidVideoId(entry.id) then return end
    self:adjustPlayerMood(-24, -0.12, -20, self.playerObj)
    self.fileNoticeText = tr("Finished watching") .. " " .. self:getVideoDisplayName(entry.id) .. "."
    self.fileNoticeTimer = 150
end

function target:completeReadableEntry(entry)
    if not entry then return end
    if entry.type == "video" then
        self:completeVideoRead(entry)
        return
    end
    if entry.type == "newspaper" then
        self:completeNewspaperRead(entry)
        return
    end
    self:completeMagazineRead(entry)
end

function target:readMagazineEntry(entry)
    if not entry or entry.type ~= "magazine" or not self:isValidMagazineType(entry.id) then return end
    if self.magazineReadInProgress then
        self:showError(tr("Already reading a magazine."))
        return
    end
    local info = ComputerModMagazineData and ComputerModMagazineData[entry.id] or nil
    local recipeCount = info and type(info.recipes) == "table" and #info.recipes or 3
    self.magazineReadInProgress = true
    self.magazineReadTimer = 0
    self.magazineReadDuration = math.max(60, recipeCount * 30)
    self.magazineReadEntry = {type = entry.type, id = entry.id, label = entry.label}
    self.fileNoticeText = tr("Reading") .. " " .. self:getMagazineDisplayName(entry.id) .. "..."
    self.fileNoticeTimer = 90
end

function target:readNewspaperEntry(entry)
    if not entry or entry.type ~= "newspaper" or not self:isValidNewspaperId(entry.id) then return end
    if self.magazineReadInProgress then
        self:showError(tr("Already reading a document."))
        return
    end
    self.magazineReadInProgress = true
    self.magazineReadTimer = 0
    self.magazineReadDuration = 90
    self.magazineReadEntry = {type = entry.type, id = entry.id, label = entry.label}
    self.fileNoticeText = tr("Reading") .. " " .. self:getNewspaperDisplayName(entry.id) .. "..."
    self.fileNoticeTimer = 90
end

function target:readVideoEntry(entry)
    if not entry or entry.type ~= "video" or not self:isValidVideoId(entry.id) then return end
    if self.magazineReadInProgress then
        self:showError(tr("Already watching something."))
        return
    end
    self.magazineReadInProgress = true
    self.magazineReadTimer = 0
    self.magazineReadDuration = 360
    self.magazineReadEntry = {type = entry.type, id = entry.id, label = entry.label}
    self.fileNoticeText = tr("Watching") .. " " .. self:getVideoDisplayName(entry.id) .. "..."
    self.fileNoticeTimer = 90
end

function target:readFolderEntry(entry)
    if not entry then return end
    if entry.type == "app" or entry.type == "folder" or entry.type == "note" or entry.type == "paint" then
        self:activateStoredEntry(entry)
        return
    end
    if entry.type == "video" then
        self:readVideoEntry(entry)
        return
    end
    if entry.type == "newspaper" then
        self:readNewspaperEntry(entry)
        return
    end
    self:readMagazineEntry(entry)
end

function target:emptyTrash()
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModTrashEntries = {}
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:restoreTrashEntry(index)
    local data = self:getComputerData()
    if not data then return end
    local trash = self:getTrashEntries()
    local entry = trash[index]
    if not entry then return end
    if entry.type == "folder" and entry.name then
        local restoredFolder = {type = "folder", name = entry.name, label = entry.name}
        if (entry.source == "folder" or entry.source == "__CD__") and entry.folderName == "__CD__" then
            local cdItems = self:getMountedDiscContents()
            cdItems[#cdItems + 1] = restoredFolder
        elseif entry.source == "folder" and entry.folderName and entry.folderName ~= "" then
            data.ComputerModFolderContents = data.ComputerModFolderContents or {}
            data.ComputerModFolderContents[entry.folderName] = data.ComputerModFolderContents[entry.folderName] or {}
            data.ComputerModFolderContents[entry.folderName][#data.ComputerModFolderContents[entry.folderName] + 1] = restoredFolder
        elseif entry.source == "__CD__" then
            local cdItems = self:getMountedDiscContents()
            cdItems[#cdItems + 1] = restoredFolder
        else
            data.ComputerModFolders = data.ComputerModFolders or {}
            data.ComputerModFolderContents = data.ComputerModFolderContents or {}
            data.ComputerModUserFolders = data.ComputerModUserFolders or {}
            local exists = false
            for i = 1, #data.ComputerModFolders do
                if data.ComputerModFolders[i] == entry.name then
                    exists = true
                    break
                end
            end
            if not exists then
                data.ComputerModFolders[#data.ComputerModFolders + 1] = entry.name
            end
            data.ComputerModFolderContents[entry.name] = entry.items or {}
            self:setDesktopItemHidden("folder:" .. tostring(entry.name), false)
        end
        if entry.userCreated then
            data.ComputerModUserFolders[entry.name] = true
        end
    elseif entry.type == "magazine" and entry.id and self:isValidMagazineType(entry.id) then
        if entry.source == "desktop" then
            self:addEntryToDesktop({type = "magazine", id = entry.id, label = entry.label, desktopKey = entry.desktopKey})
        elseif (entry.source == "folder" or entry.source == "__CD__") and entry.folderName == "__CD__" then
            local cdItems = self:getMountedDiscContents()
            cdItems[#cdItems + 1] = {type = "magazine", id = entry.id, label = entry.label}
        elseif entry.source == "folder" and entry.folderName and entry.folderName ~= "" then
            data.ComputerModFolderContents = data.ComputerModFolderContents or {}
            data.ComputerModFolderContents[entry.folderName] = data.ComputerModFolderContents[entry.folderName] or {}
            data.ComputerModFolderContents[entry.folderName][#data.ComputerModFolderContents[entry.folderName] + 1] = {type = "magazine", id = entry.id, label = entry.label}
        else
            local downloads = self:getDownloadedMagazines()
            downloads[#downloads + 1] = {type = "magazine", id = entry.id, label = entry.label}
            data.ComputerModDownloadedMagazines = downloads
        end
    elseif entry.type == "newspaper" and entry.id and self:isValidNewspaperId(entry.id) then
        if entry.source == "desktop" then
            self:addEntryToDesktop({type = "newspaper", id = entry.id, label = entry.label, desktopKey = entry.desktopKey})
        elseif (entry.source == "folder" or entry.source == "__CD__") and entry.folderName == "__CD__" then
            local cdItems = self:getMountedDiscContents()
            cdItems[#cdItems + 1] = {type = "newspaper", id = entry.id, label = entry.label}
        elseif entry.source == "folder" and entry.folderName and entry.folderName ~= "" then
            data.ComputerModFolderContents = data.ComputerModFolderContents or {}
            data.ComputerModFolderContents[entry.folderName] = data.ComputerModFolderContents[entry.folderName] or {}
            data.ComputerModFolderContents[entry.folderName][#data.ComputerModFolderContents[entry.folderName] + 1] = {type = "newspaper", id = entry.id, label = entry.label}
        else
            local downloads = self:getDownloadedMagazines()
            downloads[#downloads + 1] = {type = "newspaper", id = entry.id, label = entry.label}
            data.ComputerModDownloadedMagazines = downloads
        end
    elseif entry.type == "video" and entry.id and self:isValidVideoId(entry.id) then
        if entry.source == "desktop" then
            self:addEntryToDesktop({type = "video", id = entry.id, label = entry.label, desktopKey = entry.desktopKey})
        elseif (entry.source == "folder" or entry.source == "__CD__") and entry.folderName == "__CD__" then
            local cdItems = self:getMountedDiscContents()
            cdItems[#cdItems + 1] = {type = "video", id = entry.id, label = entry.label}
        elseif entry.source == "folder" and entry.folderName and entry.folderName ~= "" then
            data.ComputerModFolderContents = data.ComputerModFolderContents or {}
            data.ComputerModFolderContents[entry.folderName] = data.ComputerModFolderContents[entry.folderName] or {}
            data.ComputerModFolderContents[entry.folderName][#data.ComputerModFolderContents[entry.folderName] + 1] = {type = "video", id = entry.id, label = entry.label}
        else
            local downloads = self:getDownloadedMagazines()
            downloads[#downloads + 1] = {type = "video", id = entry.id, label = entry.label}
            data.ComputerModDownloadedMagazines = downloads
        end
    elseif entry.type == "paint" and entry.name and entry.cells then
        if (entry.source == "folder" or entry.source == "__CD__") and entry.folderName == "__CD__" then
            local cdItems = self:getMountedDiscContents()
            cdItems[#cdItems + 1] = cloneComputerEntry(entry)
        elseif entry.source == "folder" and entry.folderName and entry.folderName ~= "" then
            data.ComputerModFolderContents = data.ComputerModFolderContents or {}
            data.ComputerModFolderContents[entry.folderName] = data.ComputerModFolderContents[entry.folderName] or {}
            data.ComputerModFolderContents[entry.folderName][#data.ComputerModFolderContents[entry.folderName] + 1] = cloneComputerEntry(entry)
        else
            local files = self:getPaintFiles()
            files[#files + 1] = {key = entry.key or self:generatePaintFileKey(), name = entry.name, width = entry.width or 24, height = entry.height or 14, cells = entry.cells}
            data.ComputerModPaintFiles = files
        end
    elseif entry.type == "app" and entry.app then
        self:setDesktopItemHidden("app_" .. tostring(entry.app), false)
    elseif entry.type == "note" and entry.key then
        if (entry.source == "folder" or entry.source == "__CD__") and entry.folderName == "__CD__" then
            local cdItems = self:getMountedDiscContents()
            cdItems[#cdItems + 1] = cloneComputerEntry(entry)
        elseif entry.source == "folder" and entry.folderName and entry.folderName ~= "" then
            data.ComputerModFolderContents = data.ComputerModFolderContents or {}
            data.ComputerModFolderContents[entry.folderName] = data.ComputerModFolderContents[entry.folderName] or {}
            data.ComputerModFolderContents[entry.folderName][#data.ComputerModFolderContents[entry.folderName] + 1] = cloneComputerEntry(entry)
        else
            local notes = self:getDesktopNotes()
            notes[#notes + 1] = {key = entry.key, name = entry.label or "Note", text = entry.text or ""}
            data.ComputerModDesktopNotes = notes
            self:setDesktopItemHidden("note:" .. tostring(entry.key), false)
        end
    end
    table.remove(trash, index)
    data.ComputerModTrashEntries = trash
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:isOSInstalled()
    if self:isNetworkTerminal() then return true end
    local data = self:getComputerData()
    if not data then return true end
    return data.ComputerModOSInstalled ~= false
end

function target:getInstalledGames()
    local data = self:getComputerData()
    if not data then return {} end
    data.ComputerModInstalledGames = data.ComputerModInstalledGames or {}
    return data.ComputerModInstalledGames
end

function target:isGameInstalled(gameId)
    local installed = self:getInstalledGames()
    for i = 1, #installed do
        if installed[i] == gameId then
            return true
        end
    end
    return false
end

function target:uninstallGame(gameId)
    local data = self:getComputerData()
    if not data or not gameId then return end
    local installed = self:getInstalledGames()
    for i = #installed, 1, -1 do
        if installed[i] == gameId then
            table.remove(installed, i)
        end
    end
    data.ComputerModInstalledGames = installed
    self.gameContextMenu = nil
    self:openGamesMenu()
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:canWriteGameToDisc(gameId)
    local data = self:getComputerData()
    return data and data.ComputerModMountedCD == "blank" and gameInstallInfo[gameId] ~= nil and gameId ~= "os"
end

function target:writeGameToMountedDisc(gameId)
    local data = self:getComputerData()
    if not data or not self:canWriteGameToDisc(gameId) then return end
    data.ComputerModMountedCD = gameId
    data.ComputerModMountedCDItem = gameDiscItems[gameId]
    data.ComputerModMountedCDLabel = gameInstallInfo[gameId].disc
    data.ComputerModMountedCDContents = nil
    self.fileNoticeText = gameInstallInfo[gameId].disc .. " " .. tr("created.")
    self.fileNoticeTimer = 150
    self.gameContextMenu = nil
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:installGame(gameId)
    local data = self:getComputerData()
    if not data then return false end
    if self:isNetworkTerminal() then return false end
    if gameId == "os" then
        data.ComputerModOSInstalled = true
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        return true
    end
    if not gameInstallInfo[gameId] then return false end
    if self:isGameInstalled(gameId) then return false end
    local installed = self:getInstalledGames()
    installed[#installed + 1] = gameId
    data.ComputerModInstalledGames = installed
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    return true
end

function target:getVisibleGames()
    local visible = {}
    for i = 1, #gameInstallOrder do
        local gameId = gameInstallOrder[i]
        if self:isGameInstalled(gameId) then
            visible[#visible + 1] = gameId
        end
    end
    return visible
end

function target:layoutVisibleGameButtons()
    local buttonMap = {
        pong = self.pongButton,
        snake = self.snakeButton,
        minesweeper = self.minesweeperButton,
        tetris = self.tetrisButton,
        space_invaders = self.spaceInvadersButton,
        doom = self.doomButton,
        racer = self.racerButton,
        flappy = self.flappyButton,
        breakout = self.breakoutButton,
        asteroids = self.asteroidsButton,
        frogger = self.froggerButton,
        missile = self.missileButton,
        lander = self.landerButton,
        circuit = self.circuitButton,
        memory = self.memoryButton,
        starpilot = self.starPilotButton,
        caverunner = self.caveRunnerButton,
        lightsout = self.lightsOutButton,
        signalmatch = self.signalMatchButton,
        boxpush = self.boxPushButton,
        tileslide = self.tileSlideButton,
        pipelink = self.pipeLinkButton,
        codebreaker = self.codeBreakerButton,
        outbreakops = self.outbreakOpsButton
    }
    local visibleGames = self:getVisibleGames()
    local slots = self:getGameIconSlots()
    for i = 1, #visibleGames do
        local gameId = visibleGames[i]
        local button = buttonMap[gameId]
        local slot = slots[i]
        if button and slot then
            button:setX(slot.x)
            button:setY(slot.y)
            button:setWidth(slot.w)
            button:setHeight(slot.h)
        end
    end
end

function target:getGameIconSlots()
    local slots = {}
    local visibleGames = self:getVisibleGames()
    local scale = tonumber(self.contentScale or self.uiScale or 1) or 1
    local count = #visibleGames
    if count == 0 then return slots end
    local marginX = math.floor(18 * scale + 0.5)
    local marginTop = math.floor(42 * scale + 0.5)
    local marginBottom = math.floor(34 * scale + 0.5)
    local availableW = math.max(120, self.screenWidth - marginX * 2)
    local availableH = math.max(100, self.screenHeight - marginTop - marginBottom)
    local baseSlotW = math.floor(60 * scale + 0.5)
    local baseSlotH = math.floor(74 * scale + 0.5)
    local minSlotW = math.floor(50 * scale + 0.5)
    local minSlotH = math.floor(58 * scale + 0.5)
    local maxRows = math.max(1, math.floor(availableH / math.max(1, minSlotH + math.floor(4 * scale + 0.5))))
    local cols = math.max(1, math.ceil(count / maxRows))
    local maxCols = math.max(1, math.floor(availableW / math.max(1, minSlotW + math.floor(8 * scale + 0.5))))
    cols = math.min(count, math.min(maxCols, math.max(cols, math.min(5, count))))
    local rows = math.max(1, math.ceil(count / cols))
    while rows > maxRows and cols < count do
        cols = cols + 1
        rows = math.ceil(count / cols)
    end
    local stepX = math.floor(availableW / math.max(1, cols))
    local stepY = math.floor(availableH / math.max(1, rows))
    local slotW = math.max(minSlotW, math.min(baseSlotW, stepX - math.floor(6 * scale + 0.5)))
    local slotH = math.max(minSlotH, math.min(baseSlotH, stepY - math.floor(4 * scale + 0.5)))
    local startX = self.screenX + marginX + math.floor(math.max(0, stepX - slotW) * 0.5)
    local startY = self.screenY + marginTop + math.floor(math.max(0, stepY - slotH) * 0.5)
    local iconSize = math.max(24, math.min(math.floor(34 * scale + 0.5), slotW - math.floor(18 * scale + 0.5), slotH - math.floor(28 * scale + 0.5)))
    for i = 1, #visibleGames do
        local gameId = visibleGames[i]
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        slots[#slots + 1] = {
            x = startX + col * stepX,
            y = startY + row * stepY,
            w = slotW,
            h = slotH,
            iconSize = iconSize,
            gameId = gameId
        }
    end
    return slots
end

function target:layoutDesktopShortcutButtons()
    local slots = (self.getDesktopGridSlots and self:getDesktopGridSlots()) or {}
    local buttonOrder = {
        self.fileButton,
        self.notepadButton,
        self.browserButton,
        self.calculatorButton,
        self.gamesMenuButton,
        self.postsButton,
        self.trashButton,
        self.musicButton,
        self.mailButton,
        self.settingsDesktopButton
    }
    for i = 1, #buttonOrder do
        local button = buttonOrder[i]
        local slot = slots[i]
        if button and slot then
            button:setX(slot.x)
            button:setY(slot.y)
            button:setWidth(slot.w)
            button:setHeight(slot.h)
        end
    end
end

function target:getGameIconAt(x, y)
    local slots = self:getGameIconSlots()
    for i = 1, #slots do
        local slot = slots[i]
        if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
            return slot.gameId
        end
    end
    return nil
end

function target:openGameContextMenu(gameId, x, y)
    if not gameId then return false end
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self.folderContextMenu = nil
    self.discContextMenu = nil
    self.gameContextMenu = {x = x, y = y, gameId = gameId}
    self:updateStartMenuButtons()
    return true
end

function target:openInstallWizard(gameId)
    if self:isNetworkTerminal() then
        self:showError(tr("This terminal runs Network Recovery only."))
        return
    end
    if not gameInstallInfo[gameId] then return end
    self.currentView = "INSTALLER"
    self.installGameId = gameId
    self.installStep = 1
    self.installInProgress = false
    self.installProgress = 0
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self.fileButton:setVisible(false)
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.gamesMenuButton:setVisible(false)
    self.pongButton:setVisible(false)
    self.snakeButton:setVisible(false)
    self.minesweeperButton:setVisible(false)
    self.tetrisButton:setVisible(false)
    self.spaceInvadersButton:setVisible(false)
    self.doomButton:setVisible(false)
    self.racerButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setResetConfirmControlsVisible(false)
    self:setInstallControlsVisible(true)
    if self.installNextButton then self.installNextButton:setTitle(tr("Next")) end
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:advanceInstallStep()
    if self.currentView == "OS_SETUP" then
        self:finishOSFirstRunSetup()
        return
    end
    if not self.installGameId then return end
    local alreadyInstalled = (self.installGameId == "os" and self:isOSInstalled()) or (self.installGameId ~= "os" and self:isGameInstalled(self.installGameId))
    if self.installInProgress then
        return
    end
    if self.installStep < 3 then
        self.installStep = self.installStep + 1
        if self.installStep == 3 and self.installNextButton then
            self.installNextButton:setTitle(alreadyInstalled and tr("Installed") or tr("Install"))
        end
        return
    end
    if alreadyInstalled then
        if self.installGameId == "os" then
            self:beginBootSequence()
        else
            self:startFiles()
        end
        return
    end
    self.currentView = "INSTALLING"
    self.installInProgress = true
    self.installProgress = 0
    self:setInstallControlsVisible(false)
end

function target:cancelInstallStep()
    if self.currentView == "OS_SETUP" then
        self:finishOSFirstRunSetup()
        return
    end
    self.installInProgress = false
    self.installProgress = 0
    if self.installGameId == "os" then
        self.installGameId = nil
        if self:isOSInstalled() then
            self:beginBootSequence()
        else
            self:showBootError()
            self:setInstallControlsVisible(false)
            self.backButton:setVisible(false)
            self.closeButton:setVisible(false)
            self:updateStartMenuButtons()
        end
        return
    end
    if not self:isOSInstalled() then
        self.installGameId = nil
        self:showBootError()
        self:setInstallControlsVisible(false)
        self.backButton:setVisible(false)
        self.closeButton:setVisible(false)
        self:updateStartMenuButtons()
        return
    end
    self:startFiles()
end

function target:ensureComputerMeta()
    local data = self:getComputerData()
    if not data then return end
    if data.ComputerModNetworkTerminal == true then
        data.ComputerModMetaInitialized = true
        if not data.ComputerModMachineID or data.ComputerModMachineID == "NET-11901-6951" then
            local square = self.computer and self.computer.getSquare and self.computer:getSquare() or nil
            if square then
                data.ComputerModMachineID = "NET-" .. tostring(square:getX()) .. "-" .. tostring(square:getY()) .. "-" .. tostring(square:getZ())
            else
                data.ComputerModMachineID = "NET-" .. tostring(data.ComputerModNetworkTerminalId or "relay")
            end
        end
        data.ComputerModOSInstalled = true
        data.ComputerModFactoryReset = false
        data.ComputerModPasswordEnabled = false
        data.ComputerModPassword = nil
        data.ComputerModUsername = "Network Admin"
        data.ComputerModInstalledGames = {}
        data.ComputerModMountedCD = nil
        data.ComputerModMountedCDItem = nil
        data.ComputerModMountedCDLabel = nil
        data.ComputerModLastView = "NETWORK_TERMINAL"
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        return
    end
    local wasPreviouslyActivated = data.ComputerModMetaInitialized == true
    if data.ComputerModStartingHouseNoPasswordPending == true then
        data.ComputerModPasswordEnabled = false
        data.ComputerModPassword = nil
        data.ComputerModStickyNoteVisible = false
        data.ComputerModStickyNotePassword = nil
        data.ComputerModStartingHouseNoPasswordPending = nil
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    if not data.ComputerModMachineID or data.ComputerModMachineID == "" then
        data.ComputerModMachineID = self:generateComputerID()
    end
    local componentChanged = ComputerModComponents.ensure(
        data,
        ComputerModComponents.getComputerSeed(data, self.computer),
        wasPreviouslyActivated,
        ComputerModComponents.getWorldAgeHours()
    )
    if ComputerModComponents.applyWear(data, ComputerModComponents.getWorldAgeHours()) then
        componentChanged = true
    end
    if componentChanged and self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    if type(data.ComputerModComponents) ~= "table" or type(data.ComputerModComponents.hardDrive) ~= "table" then
        return
    end
    if data.ComputerModMetaInitialized then
        if data.ComputerModStickyNoteInitialized ~= true then
            data.ComputerModStickyNoteInitialized = true
            data.ComputerModStickyNoteVisible = false
            data.ComputerModStickyNotePassword = nil
            if self.computer then
                ComputerModComputerTypes.transmitData(self.computer)
            end
        end
        if type(data.ComputerModPaintFiles) ~= "table" then
            data.ComputerModPaintFiles = {}
        end
        if data.ComputerModPaintSpawnInitialized == nil then
            data.ComputerModPaintSpawnInitialized = true
            if not data.ComputerModFactoryReset and ZombRand(100) < ComputerModSandbox.getPercent("PaintFileChance") then
                data.ComputerModPaintFiles[#data.ComputerModPaintFiles + 1] = self:generateRandomPaintFile()
                if ZombRand(100) < 18 then
                    data.ComputerModPaintFiles[#data.ComputerModPaintFiles + 1] = self:generateRandomPaintFile()
                end
            end
            if self.computer then
                ComputerModComputerTypes.transmitData(self.computer)
            end
        end
        local notepadChanged = false
        if data.ComputerModNotepadInitialized ~= true then
            if data.ComputerModFactoryReset == true then
                data.ComputerModNotepadText = ""
            elseif not data.ComputerModNotepadText or data.ComputerModNotepadText == "" then
                data.ComputerModNotepadText = self:generateRoomNoteText()
            end
            data.ComputerModNotepadInitialized = true
            notepadChanged = true
        end
        if data.ComputerModNotepadSeedRepairV1 ~= true then
            if data.ComputerModFactoryReset ~= true and (not data.ComputerModNotepadText or data.ComputerModNotepadText == "") then
                data.ComputerModNotepadText = self:generateRoomNoteText()
                data.ComputerModNotepadInitialized = true
            end
            data.ComputerModNotepadSeedRepairV1 = true
            notepadChanged = true
        end
        if notepadChanged then
            if self.computer then
                ComputerModComputerTypes.transmitData(self.computer)
            end
            if self.syncNotepadDataToServer then
                self:syncNotepadDataToServer()
            end
        end
        ComputerModComponents.captureDriveData(data)
        return
    end

    data.ComputerModMetaInitialized = true
    data.ComputerModMachineID = data.ComputerModMachineID or self:generateComputerID()
    if type(data.ComputerModFolders) ~= "table" then
        if self.generateRoomFolders then
            data.ComputerModFolders = self:generateRoomFolders()
        else
            data.ComputerModFolders = {}
        end
    end
    if data.ComputerModPasswordEnabled == nil then
        data.ComputerModPasswordEnabled = ZombRand(100) < ComputerModSandbox.getPercent("PasswordChance")
    end
    if data.ComputerModPasswordEnabled and (not data.ComputerModPassword or data.ComputerModPassword == "") then
        data.ComputerModPassword = self:generateComputerPassword()
    elseif not data.ComputerModPasswordEnabled then
        data.ComputerModPassword = nil
    end
    data.ComputerModStickyNoteInitialized = true
    if data.ComputerModPasswordEnabled == true and data.ComputerModPassword and data.ComputerModPassword ~= "" and ZombRand(100) < ComputerModSandbox.getPercent("FramePasswordNoteChance") then
        data.ComputerModStickyNoteVisible = true
        data.ComputerModStickyNotePassword = tostring(data.ComputerModPassword)
    else
        data.ComputerModStickyNoteVisible = false
        data.ComputerModStickyNotePassword = nil
    end
    data.ComputerModInstalledGames = data.ComputerModInstalledGames or self:generateInstalledGames()
    if not data.ComputerModMountedCD then
        data.ComputerModMountedCDItem = nil
        data.ComputerModMountedCDLabel = nil
        data.ComputerModMountedCDContents = nil
    end
    if data.ComputerModOSInstalled == nil then
        data.ComputerModOSInstalled = true
    end
    if data.ComputerModFactoryReset == nil then
        data.ComputerModFactoryReset = false
    end
    if data.ComputerModFactoryReset == true then
        data.ComputerModNotepadText = ""
        data.ComputerModNotepadInitialized = true
    elseif data.ComputerModNotepadInitialized ~= true then
        if not data.ComputerModNotepadText or data.ComputerModNotepadText == "" then
            data.ComputerModNotepadText = self:generateRoomNoteText()
        end
        data.ComputerModNotepadInitialized = true
    elseif data.ComputerModNotepadText == nil then
        data.ComputerModNotepadText = ""
    end
    data.ComputerModNotepadSeedRepairV1 = true
    if type(data.ComputerModDesktopNotes) ~= "table" then
        data.ComputerModDesktopNotes = {}
    end
    if type(data.ComputerModPaintFiles) ~= "table" then
        data.ComputerModPaintFiles = {}
    end
    if data.ComputerModPaintSpawnInitialized == nil then
        data.ComputerModPaintSpawnInitialized = true
        if not data.ComputerModFactoryReset and ZombRand(100) < ComputerModSandbox.getPercent("PaintFileChance") then
            data.ComputerModPaintFiles[#data.ComputerModPaintFiles + 1] = self:generateRandomPaintFile()
            if ZombRand(100) < 18 then
                data.ComputerModPaintFiles[#data.ComputerModPaintFiles + 1] = self:generateRandomPaintFile()
            end
        end
    end
    if (not data.ComputerModCalculatorDisplay or data.ComputerModCalculatorDisplay == "") and not data.ComputerModFactoryReset then
        data.ComputerModCalculatorDisplay = self:generateCalculatorHistoryDisplay()
    end
    data.ComputerModMuteMusic = data.ComputerModMuteMusic == true
    data.ComputerModUse24HourClock = data.ComputerModUse24HourClock == true
    data.ComputerModMonthFirstDate = data.ComputerModMonthFirstDate == true
    data.ComputerModTextSize = math.floor(tonumber(data.ComputerModTextSize or 2) or 2)
    if data.ComputerModTextSize < 1 or data.ComputerModTextSize > #textSizeScales then data.ComputerModTextSize = 2 end
    data.ComputerModUIScale = math.floor(tonumber(data.ComputerModUIScale or 1) or 1)
    if data.ComputerModUIScale < 1 or data.ComputerModUIScale > #uiScaleOptions then data.ComputerModUIScale = 1 end
    if not data.ComputerModUsername or data.ComputerModUsername == "" or data.ComputerModUsername == "User" then
        data.ComputerModUsername = periodComputerNames[ZombRand(#periodComputerNames) + 1]
    end
    if not data.ComputerModAvatar then
        data.ComputerModAvatar = ZombRand(6) + 1
    end
    data.ComputerModAvatar = tonumber(data.ComputerModAvatar or 1) or 1
    if not data.ComputerModBackgroundPalette then
        data.ComputerModBackgroundPalette = ZombRand(#backgroundPalettes) + 1
    end
    data.ComputerModBrowserAddress = data.ComputerModBrowserAddress or "knox-weather.net"
    if data.ComputerModMailSpawnInitialized == nil then
        data.ComputerModMailSpawnInitialized = true
        if ZombRand(100) < ComputerModSandbox.getPercent("MailAccountChance") then
            local baseName = string.lower(string.gsub(data.ComputerModUsername or "user", "%s+", ""))
            data.ComputerModMailAddress = baseName .. tostring(ZombRand(10, 99)) .. "@knoxmail.local"
            data.ComputerModMailPassword = easyComputerPasswords[ZombRand(#easyComputerPasswords) + 1]
            data.ComputerModMailLoggedIn = ZombRand(100) < ComputerModSandbox.getPercent("MailLoggedInChance")
            data.ComputerModMailPlayerCreated = false
            if data.ComputerModMailMessages == nil then
                data.ComputerModMailMessages = self:generateRoomMailMessages()
            end
            if data.ComputerModMailLoggedIn then
                data.ComputerModMailSessionAddress = data.ComputerModMailAddress
            end
        else
            data.ComputerModMailAddress = nil
            data.ComputerModMailPassword = nil
            data.ComputerModMailLoggedIn = false
            data.ComputerModMailSessionAddress = nil
            data.ComputerModMailPlayerCreated = false
            data.ComputerModMailMessages = nil
        end
    end
    if data.ComputerModMailLoggedIn and (not data.ComputerModMailSessionAddress or data.ComputerModMailSessionAddress == "") and data.ComputerModMailAddress and data.ComputerModMailAddress ~= "" then
        data.ComputerModMailSessionAddress = data.ComputerModMailAddress
    end
    if not data.ComputerModMailLoggedIn then
        data.ComputerModMailSessionAddress = nil
    end
    data.ComputerModChatLoggedIn = data.ComputerModChatLoggedIn == true
    if not data.ComputerModChatLoggedIn then
        data.ComputerModChatSessionUser = nil
    end
    if self.ensureFolderData then
        self:ensureFolderData()
    end
    if self.syncComputerMailAccount and data.ComputerModMailAddress and data.ComputerModMailAddress ~= "" then
        self:syncComputerMailAccount()
    end
    ComputerModComponents.captureDriveData(data)
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:updateComponentWear()
    local data = self:getComputerData()
    if not data or self:isNetworkTerminal() then return false end
    local changed = ComputerModComponents.applyWear(data, ComputerModComponents.getWorldAgeHours())
    if changed then
        ComputerModComponents.captureDriveData(data)
        if self.computer then ComputerModComputerTypes.transmitData(self.computer) end
    end
    return changed
end

function target:getComponentBootFailure()
    local data = self:getComputerData()
    if not data or self:isNetworkTerminal() then return nil end
    self:updateComponentWear()
    return ComputerModComponents.getBootFailure(data)
end

function target:getComputerFolders()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModFolders) ~= "table" then data.ComputerModFolders = {} end
    if self.ensureFolderData then self:ensureFolderData() end
    local hasDownloads = false
    for i = 1, #data.ComputerModFolders do
        if data.ComputerModFolders[i] == "Downloads" then
            hasDownloads = true
            break
        end
    end
    if not hasDownloads then
        table.insert(data.ComputerModFolders, 1, "Downloads")
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    return data.ComputerModFolders
end

function target:getDesktopNotes()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModDesktopNotes) ~= "table" then
        data.ComputerModDesktopNotes = {}
    end
    return data.ComputerModDesktopNotes
end

function target:getDesktopNoteByKey(noteKey)
    if not noteKey or noteKey == "" then return nil end
    local notes = self:getDesktopNotes()
    for i = 1, #notes do
        if notes[i] and notes[i].key == noteKey then
            return notes[i], i
        end
    end
    return nil, nil
end

function target:generateDesktopNoteKey()
    local base = getTimestampMs and getTimestampMs() or math.floor((getComputerWorldAgeHours and getComputerWorldAgeHours()) or 0)
    return "note_" .. tostring(base) .. "_" .. tostring(1000 + ZombRand(9000))
end

function target:getPaintFiles()
    local data = self:getComputerData()
    if not data then return {} end
    if type(data.ComputerModPaintFiles) ~= "table" then
        data.ComputerModPaintFiles = {}
    end
    return data.ComputerModPaintFiles
end

function target:getPaintFileByKey(fileKey)
    if not fileKey or fileKey == "" then return nil end
    local files = self:getPaintFiles()
    for i = 1, #files do
        if files[i] and files[i].key == fileKey then
            return files[i], i
        end
    end
    return nil, nil
end

function target:generatePaintFileKey()
    local base = getTimestampMs and getTimestampMs() or math.floor((getComputerWorldAgeHours and getComputerWorldAgeHours()) or 0)
    return "paint_" .. tostring(base) .. "_" .. tostring(1000 + ZombRand(9000))
end

function target:generateRandomPaintFile()
    local file = {key = self:generatePaintFileKey(), name = "Paint " .. tostring(10 + ZombRand(90)), width = 32, height = 18, cells = {}}
    local names = {"Sketch", "Map", "House", "Logo", "Flower", "Car", "Dog", "Sunset", "Tower", "Face", "Road", "Tree"}
    file.name = names[ZombRand(#names) + 1] .. " " .. tostring(1 + ZombRand(9))
    local function setCell(x, y, color)
        if x >= 1 and x <= file.width and y >= 1 and y <= file.height then
            file.cells[tostring(x) .. ":" .. tostring(y)] = color
        end
    end
    local pattern = ZombRand(12) + 1
    if pattern == 1 then
        for x = 8, 24 do setCell(x, 13, 4) end
        for y = 8, 13 do setCell(9, y, 4); setCell(23, y, 4) end
        for x = 7, 25 do setCell(x, 7 + math.abs(16 - x), 2) end
        for x = 14, 17 do for y = 10, 13 do setCell(x, y, 6) end end
    elseif pattern == 2 then
        for x = 6, 26 do setCell(x, 6, 3); setCell(x, 14, 3) end
        for y = 6, 14 do setCell(6, y, 3); setCell(26, y, 3) end
        for x = 10, 22 do setCell(x, 10 + ZombRand(-2, 3), 5) end
    elseif pattern == 3 then
        for y = 6, 15 do setCell(16, y, 4) end
        for x = 9, 23 do setCell(x, 15, 4) end
        for x = 11, 21 do setCell(x, 9 + math.floor(math.abs(16 - x) * 0.35), 2) end
        for x = 12, 20 do setCell(x, 8 + math.floor(math.abs(16 - x) * 0.35), 2) end
    elseif pattern == 4 then
        for x = 9, 23 do setCell(x, 12, 6); setCell(x, 13, 6) end
        for x = 12, 20 do setCell(x, 9, 7); setCell(x, 10, 7) end
        setCell(10, 11, 1); setCell(22, 11, 1); setCell(14, 8, 1); setCell(18, 8, 1)
    elseif pattern == 5 then
        for x = 3, 30 do setCell(x, 14, 5) end
        for x = 4, 12 do setCell(x, 13 - math.floor((x - 4) * 0.45), 5) end
        for x = 20, 30 do setCell(x, 9 + math.floor((x - 20) * 0.4), 5) end
        for y = 4, 8 do setCell(24, y, 4); setCell(25, y, 4) end
        for x = 21, 28 do setCell(x, 4, 2) end
    elseif pattern == 6 then
        for x = 8, 24 do setCell(x, 5, 3); setCell(x, 14, 3) end
        for y = 5, 14 do setCell(8, y, 3); setCell(24, y, 3) end
        for x = 11, 14 do setCell(x, 8, 1) end
        for x = 18, 21 do setCell(x, 8, 1) end
        for x = 12, 20 do setCell(x, 12 + math.floor(math.abs(16 - x) * 0.2), 6) end
    elseif pattern == 7 then
        for x = 5, 27 do setCell(x, 15, 2) end
        for y = 6, 15 do setCell(15, y, 4); setCell(16, y, 4); setCell(17, y, 4) end
        for x = 9, 23 do setCell(x, 8 + math.floor(math.abs(16 - x) * 0.55), 2) end
        for x = 11, 21 do setCell(x, 7 + math.floor(math.abs(16 - x) * 0.4), 5) end
    elseif pattern == 8 then
        for y = 3, 14 do setCell(8, y, 7); setCell(24, y, 7) end
        for x = 8, 24 do setCell(x, 3, 7); setCell(x, 14, 7) end
        for x = 10, 22, 3 do for y = 5, 12, 3 do setCell(x, y, 1 + ZombRand(6)) end end
    elseif pattern == 9 then
        for x = 4, 28 do setCell(x, 13, 6); setCell(x, 14, 6) end
        for x = 7, 12 do setCell(x, 10, 3); setCell(x, 11, 3) end
        for x = 18, 25 do setCell(x, 8, 4); setCell(x, 9, 4); setCell(x, 10, 4) end
        for x = 6, 26, 5 do setCell(x, 12, 1) end
    elseif pattern == 10 then
        for x = 11, 21 do setCell(x, 4, 4); setCell(x, 14, 4) end
        for y = 5, 13 do setCell(10, y, 4); setCell(22, y, 4) end
        for x = 12, 20 do setCell(x, 6, 2); setCell(x, 12, 2) end
        for y = 7, 11 do setCell(14, y, 2); setCell(18, y, 2) end
    elseif pattern == 11 then
        for x = 3, 29 do setCell(x, 7 + math.floor(math.sin(x * 0.5) * 2), 5) end
        for x = 3, 29 do setCell(x, 11 + math.floor(math.sin(x * 0.4) * 2), 6) end
        for x = 4, 10 do setCell(x, 5, 3) end
        for x = 22, 29 do setCell(x, 14, 2) end
    else
        for i = 1, 34 do
            setCell(2 + ZombRand(file.width - 3), 2 + ZombRand(file.height - 3), 1 + ZombRand(8))
        end
        for x = 5, 27 do setCell(x, 4 + math.floor(math.sin(x * 0.6) * 3) + 6, 5) end
    end
    return file
end

function target:addPaintFileToTrash(file)
    local data = self:getComputerData()
    if not data or not file then return end
    local trash = self:getTrashEntries()
    trash[#trash + 1] = {type = "paint", name = file.name, width = file.width, height = file.height, cells = file.cells}
    data.ComputerModTrashEntries = trash
end

function target:deletePaintFileByKey(fileKey, skipTrash)
    local data = self:getComputerData()
    if not data then return false end
    local files = self:getPaintFiles()
    for i = #files, 1, -1 do
        if files[i] and files[i].key == fileKey then
            if not skipTrash then
                self:addPaintFileToTrash(files[i])
            end
            table.remove(files, i)
            data.ComputerModPaintFiles = files
            if self.activePaintKey == fileKey then
                self.activePaintKey = nil
            end
            if self.computer then
                ComputerModComputerTypes.transmitData(self.computer)
            end
            return true
        end
    end
    return false
end

function target:hasPassword()
    local data = self:getComputerData()
    return data and data.ComputerModPasswordEnabled == true and data.ComputerModPassword and data.ComputerModPassword ~= ""
end

function target:isPasswordUnlocked()
    return self.passwordUnlocked == true or not self:hasPassword()
end

function target:getPasswordStatusText()
    if self.currentView == "LOCK" then
        return "Enter the computer password to continue."
    end
    if self:hasPassword() then
        return "Password protection is enabled."
    end
    return "This computer has no password."
end

function target:isMusicMuted()
    local data = self:getComputerData()
    if not data then return false end
    return data.ComputerModMuteMusic == true
end

function target:is24HourClock()
    local data = self:getComputerData()
    if not data then return false end
    return data.ComputerModUse24HourClock == true
end

function target:isFirmwareView()
    if self.currentView == "BIOS" or self.currentView == "BOOT_ERROR" or self.currentView == "HARDWARE_ERROR" then
        return true
    end
    if self.currentView == "NETWORK_TERMINAL" or self.currentView == "NETWORK_REPAIR" then
        return true
    end
    if self.currentView == "OS_SETUP" then
        return true
    end
    if (self.currentView == "INSTALLER" or self.currentView == "INSTALLING") and self.installGameId == "os" then
        return true
    end
    if (self.currentView == "RESET_CONFIRM" or self.currentView == "RESETTING") and self.resetReturnView == "BIOS" then
        return true
    end
    return false
end

end
