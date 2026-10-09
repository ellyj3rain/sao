function ComputerModInstallUIApps(target)
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
    local startIconTexture = shared.startIconTexture
    local userTextures = shared.userTextures
    local easyComputerPasswords = shared.easyComputerPasswords
    local periodComputerNames = shared.periodComputerNames
    local backgroundPalettes = shared.backgroundPalettes
    local gameInstallOrder = shared.gameInstallOrder
    local gameInstallInfo = shared.gameInstallInfo
    local gameDownloadInfo = shared.gameDownloadInfo
    local gameDiscItems = shared.gameDiscItems
function target:stopGameMusic()
    if not self.gameMusicID then return end
    if self.gameMusicEmitter and self.gameMusicEmitter.stopSound then
        pcall(function() self.gameMusicEmitter:stopSound(self.gameMusicID) end)
    elseif getSoundManager then
        pcall(function() getSoundManager():stopUISound(self.gameMusicID) end)
    end
    self.gameMusicID = nil
    self.gameMusicEmitter = nil
end

function target:playGameMusic()
    if self:isMusicMuted() then return end
    self:stopGameMusic()
    if getSoundManager then
        local ok, soundId = pcall(function() return getSoundManager():playUISound("ComputerPongSong") end)
        if ok then
            self.gameMusicEmitter = nil
            self.gameMusicID = soundId
            return
        end
    end
end

function target:updateBrowserMediaButton()
    if self.browserMediaButton then
        self.browserMediaButton:setVisible(false)
    end
end

function target:updateBrowserDownloadButton()
    if not self.browserDownloadButton then return end
    if self.browserCurrentAddress == "knoxshare.bbs" then
        self.browserDownloadButton:setTitle(tr("Download"))
    elseif ComputerModVideoSites and ComputerModVideoSites[self.browserCurrentAddress or ""] then
        self.browserDownloadButton:setTitle(tr("Save Tape"))
    elseif ComputerModMagazineSites and ComputerModMagazineSites[self.browserCurrentAddress or ""] then
        self.browserDownloadButton:setTitle(tr("Save Copy"))
    end
end

function target:openCurrentBrowserMedia()
    if self.browserMediaButton then
        self.browserMediaButton:setVisible(false)
    end
end

function target:setCalculatorButtonsVisible(visible)
    if not self.calculatorButtons then return end
    for i = 1, #self.calculatorButtons do
        self.calculatorButtons[i]:setVisible(visible)
    end
end

function target:startFiles()
    if not self:isOSInstalled() then
        self:showBootError()
        self.startMenuOpen = false
        self.settingsMenuOpen = false
        self:setInstallControlsVisible(false)
        self:setPasswordControlsVisible(false)
        self:setResetConfirmControlsVisible(false)
        self.backButton:setVisible(false)
        self.closeButton:setVisible(false)
        self:updateStartMenuButtons()
        return
    end
    self:saveCurrentNote()
    self.currentView = "FILES"
    self.currentFolderName = nil
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
    self.backButton:setVisible(true)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:moveCloseToWindow()
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:getDownloadedInstallers()
    local data = self:getComputerData()
    if not data then return {} end
    data.ComputerModDownloadedInstallers = data.ComputerModDownloadedInstallers or {}
    return data.ComputerModDownloadedInstallers
end

function target:isInstallerDownloaded(gameId)
    local installers = self:getDownloadedInstallers()
    for i = 1, #installers do
        if installers[i] == gameId then return true end
    end
    return false
end

function target:addDownloadedInstaller(gameId)
    if not gameInstallInfo[gameId] or self:isInstallerDownloaded(gameId) then return end
    local installers = self:getDownloadedInstallers()
    installers[#installers + 1] = gameId
    local data = self:getComputerData()
    if data then
        data.ComputerModDownloadedInstallers = installers
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
end

function target:openDownloadsFolder()
    self.currentView = "DOWNLOADS"
    self.currentFolderName = nil
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
    self.flappyButton:setVisible(false)
    self.backButton:setVisible(true)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:moveCloseToWindow()
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:getDownloadedInstallerSlots()
    local slots = {}
    local installers = self:getDownloadedInstallers()
    local scale = math.max(1, tonumber(self.contentScale or self.uiScale or 1) or 1)
    local function u(value) return math.floor(value * scale + 0.5) end
    local lineH = ComputerModUIText and ComputerModUIText.getLineHeight and ComputerModUIText.getLineHeight(UIFont.Small) or u(14)
    local itemH = math.max(u(34), lineH * 2 + u(4))
    local bodyX = self.clientX + u(10)
    local bodyY = self.clientY + u(44)
    local columns = 3
    local stepX = u(138)
    local stepY = itemH + u(8)
    for i = 1, #installers do
        local col = (i - 1) % columns
        local row = math.floor((i - 1) / columns)
        slots[i] = {x = bodyX + col * stepX, y = bodyY + row * stepY, w = u(128), h = itemH, gameId = installers[i]}
    end
    return slots
end

function target:getDownloadedInstallerAt(x, y)
    local slots = self:getDownloadedInstallerSlots()
    for i = 1, #slots do
        local slot = slots[i]
        if x >= slot.x and x <= slot.x + slot.w and y >= slot.y and y <= slot.y + slot.h then
            return slot.gameId
        end
    end
    return nil
end

function target:startCalculator()
    self:saveCurrentNote()
    self.currentView = "CALCULATOR"
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
    self.backButton:setVisible(true)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    local data = self:getComputerData()
    if data and data.ComputerModFactoryReset == true then
        data.ComputerModCalculatorDisplay = "0"
    elseif data and (not data.ComputerModCalculatorDisplay or data.ComputerModCalculatorDisplay == "") then
        data.ComputerModCalculatorDisplay = self:generateCalculatorHistoryDisplay()
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    self.calculatorDisplay = data and data.ComputerModCalculatorDisplay or "0"
    self.calculatorStoredValue = nil
    self.calculatorOperator = nil
    self.calculatorResetDisplay = false
    self:setCalculatorButtonsVisible(true)
    self:moveCloseToWindow()
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:minimizeCurrentWindow()
    if not self:canMinimizeCurrentView() or self:isViewMinimized(self.currentView) then return end
    local windows = self:getMinimizedWindows()
    if #windows >= 3 then
        self:showError(tr("Only 3 windows can be minimized."))
        return
    end
    local windowEntry = {view = self.currentView, label = self:getWindowTitleForView(self.currentView), installGameId = self.installGameId, installStep = self.installStep, folderName = self.currentFolderName}
    if self.currentView == "PAINT" then
        windowEntry.paintKey = self.activePaintKey
        windowEntry.paintW = self.paintCanvasW
        windowEntry.paintH = self.paintCanvasH
        windowEntry.paintColor = self.paintColor
        windowEntry.paintCanvas = {}
        for key, value in pairs(self.paintCanvas or {}) do
            windowEntry.paintCanvas[key] = value
        end
    end
    table.insert(windows, windowEntry)
    if self:isGameView() then
        self:setActiveGamePanelsVisible(false)
    end
    self:showDesktopHome()
    self:saveSessionView()
end

function target:restoreMinimizedWindow(index)
    local windows = self:getMinimizedWindows()
    local item = windows[index or 1]
    if item then
        table.remove(windows, index or 1)
    end
    local view = item and item.view or nil
    if not view then return end

    if view == "FILES" then
        self:startFiles()
    elseif view == "DOWNLOADS" then
        self:openDownloadsFolder()
    elseif view == "FOLDER" then
        self:openFolderView(item.folderName or self.currentFolderName or "Folder")
    elseif view == "NOTEPAD" then
        self:startNotepad()
    elseif view == "BROWSER" then
        self:startBrowser()
    elseif view == "CALCULATOR" then
        self:startCalculator()
    elseif view == "SETTINGS" then
        self:openSettingsWindow()
    elseif view == "CHAT" then
        self:startChat()
    elseif view == "MAIL" then
        self:startMail()
    elseif view == "BOARD" then
        self:startPostsBoard()
    elseif view == "MARKET" then
        self:startMarket()
    elseif view == "PAINT" then
        self:startPaint()
        self.activePaintKey = item.paintKey
        self.paintCanvasW = item.paintW or self.paintCanvasW
        self.paintCanvasH = item.paintH or self.paintCanvasH
        self.paintColor = item.paintColor or self.paintColor
        self.paintCanvas = {}
        if type(item.paintCanvas) == "table" then
            for key, value in pairs(item.paintCanvas) do
                self.paintCanvas[key] = value
            end
        end
    elseif view == "MUSIC" then
        self:startMusicPlayer()
    elseif view == "TRASH" then
        self:openTrashFolder()
    elseif view == "GAMES" then
        self:openGamesMenu()
    elseif view == "INSTALLER" then
        self:openInstallWizard(item.installGameId or self.installGameId or "pong")
        self.installStep = item.installStep or self.installStep or 1
    elseif view == "INSTALLING" then
        self.installGameId = item.installGameId or self.installGameId
        self.currentView = "INSTALLING"
        self.startMenuOpen = false
        self.settingsMenuOpen = false
        self:setInstallControlsVisible(false)
        self:moveCloseToWindow()
        self.backButton:setVisible(false)
        self.closeButton:setVisible(false)
    elseif view == "PONG" or view == "SNAKE" or view == "MINESWEEPER" or view == "TETRIS" or view == "SPACE_INVADERS" or view == "DOOM" or view == "RACER" or view == "FLAPPY" or view == "BREAKOUT" or view == "ASTEROIDS" or view == "FROGGER" or view == "MISSILE" or view == "LANDER" or view == "CIRCUIT" or view == "MEMORY" or view == "STARPILOT" or view == "CAVERUNNER" or view == "LIGHTSOUT" or view == "SIGNALMATCH" or view == "BOXPUSH" or view == "TILESLIDE" or view == "PIPELINK" or view == "CODEBREAKER" or view == "OUTBREAKOPS" then
        if view == "PONG" and not self.pongInstance then self:startPong(); self:saveSessionView(); return end
        if view == "SNAKE" and not self.snakeInstance then self:startSnake(); self:saveSessionView(); return end
        if view == "MINESWEEPER" and not self.minesweeperInstance then self:startMinesweeper(); self:saveSessionView(); return end
        if view == "TETRIS" and not self.tetrisInstance then self:startTetris(); self:saveSessionView(); return end
        if view == "SPACE_INVADERS" and not self.spaceInvadersInstance then self:startSpaceInvaders(); self:saveSessionView(); return end
        if view == "DOOM" and not self.doomInstance then self:startDoom(); self:saveSessionView(); return end
        if view == "RACER" and not self.racerInstance then self:startRacer(); self:saveSessionView(); return end
        if view == "FLAPPY" and not self.flappyInstance then self:startFlappy(); self:saveSessionView(); return end
        if view == "BREAKOUT" and not self.breakoutInstance then self:startBreakout(); self:saveSessionView(); return end
        if view == "ASTEROIDS" and not self.asteroidsInstance then self:startAsteroids(); self:saveSessionView(); return end
        if view == "FROGGER" and not self.froggerInstance then self:startFrogger(); self:saveSessionView(); return end
        if view == "MISSILE" and not self.missileInstance then self:startMissileCommand(); self:saveSessionView(); return end
        if view == "LANDER" and not self.landerInstance then self:startLunarLander(); self:saveSessionView(); return end
        if view == "CIRCUIT" and not self.circuitInstance then self:startCircuitRunner(); self:saveSessionView(); return end
        if view == "MEMORY" and not self.memoryInstance then self:startMemoryMatch(); self:saveSessionView(); return end
        if view == "STARPILOT" and not self.starPilotInstance then self:startStarPilot(); self:saveSessionView(); return end
        if view == "CAVERUNNER" and not self.caveRunnerInstance then self:startCaveRunner(); self:saveSessionView(); return end
        if view == "LIGHTSOUT" and not self.lightsOutInstance then self:startLightsOut(); self:saveSessionView(); return end
        if view == "SIGNALMATCH" and not self.signalMatchInstance then self:startSignalMatch(); self:saveSessionView(); return end
        if view == "BOXPUSH" and not self.boxPushInstance then self:startBoxPush(); self:saveSessionView(); return end
        if view == "TILESLIDE" and not self.tileSlideInstance then self:startTileSlide(); self:saveSessionView(); return end
        if view == "PIPELINK" and not self.pipeLinkInstance then self:startPipeLink(); self:saveSessionView(); return end
        if view == "CODEBREAKER" and not self.codeBreakerInstance then self:startCodeBreaker(); self:saveSessionView(); return end
        if view == "OUTBREAKOPS" and not self.outbreakOpsInstance then self:startOutbreakOps(); self:saveSessionView(); return end
        self.currentView = view
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
        self.notepadEntry:setVisible(false)
        self.browserAddressEntry:setVisible(false)
        self.browserGoButton:setVisible(false)
        self.browserMediaButton:setVisible(false)
        self:setCalculatorButtonsVisible(false)
        self:setActiveGamePanelsVisible(true)
        self:moveCloseToWindow()
        self.closeButton:setVisible(true)
    else
        self:showDesktopHome()
    end
    self:updateStartMenuButtons()
    self:saveSessionView()
end

function target:applyCalculatorOperation(value)
    if self.calculatorStoredValue == nil then
        self.calculatorStoredValue = value
        return value
    end
    local result = self.calculatorStoredValue
    if self.calculatorOperator == "+" then
        result = self.calculatorStoredValue + value
    elseif self.calculatorOperator == "-" then
        result = self.calculatorStoredValue - value
    elseif self.calculatorOperator == "*" then
        result = self.calculatorStoredValue * value
    elseif self.calculatorOperator == "/" then
        if value == 0 then
            result = 0
        else
            result = self.calculatorStoredValue / value
        end
    end
    self.calculatorStoredValue = result
    return result
end

function target:onCalculatorButton(button)
    local value = button and button.internal or ""
    if value == "C" then
        self.calculatorDisplay = "0"
        self.calculatorStoredValue = nil
        self.calculatorOperator = nil
        self.calculatorResetDisplay = false
        return
    end

    if value == "+" or value == "-" or value == "*" or value == "/" then
        local currentNumber = tonumber(self.calculatorDisplay) or 0
        self:applyCalculatorOperation(currentNumber)
        self.calculatorOperator = value
        self.calculatorResetDisplay = true
        self.calculatorDisplay = tostring(self.calculatorStoredValue or currentNumber)
        return
    end

    if value == "=" then
        if self.calculatorOperator then
            local result = self:applyCalculatorOperation(tonumber(self.calculatorDisplay) or 0)
            if math.floor(result) == result then
                self.calculatorDisplay = tostring(math.floor(result))
            else
                self.calculatorDisplay = string.format("%.2f", result)
            end
            self.calculatorStoredValue = nil
            self.calculatorOperator = nil
            self.calculatorResetDisplay = true
        end
        return
    end

    if self.calculatorResetDisplay or self.calculatorDisplay == "0" then
        self.calculatorDisplay = value
        self.calculatorResetDisplay = false
    else
        self.calculatorDisplay = self.calculatorDisplay .. value
    end
end

function target:startPong()
    self:saveCurrentNote()
    self.currentView = "PONG"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.pongInstance = PZPongGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.pongInstance:initialise()
    self:addChild(self.pongInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startSnake()
    self:saveCurrentNote()
    self.currentView = "SNAKE"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.snakeInstance = PZSnakeGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.snakeInstance:initialise()
    self:addChild(self.snakeInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startMinesweeper()
    self:saveCurrentNote()
    self.currentView = "MINESWEEPER"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.minesweeperInstance = PZMinesweeperGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.minesweeperInstance:initialise()
    self:addChild(self.minesweeperInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:updateStartMenuButtons()
end

function target:startTetris()
    self:saveCurrentNote()
    self.currentView = "TETRIS"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.tetrisInstance = PZTetrisGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.tetrisInstance:initialise()
    self:addChild(self.tetrisInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startSpaceInvaders()
    self:saveCurrentNote()
    self.currentView = "SPACE_INVADERS"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.spaceInvadersInstance = PZSpaceInvadersGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.spaceInvadersInstance:initialise()
    self:addChild(self.spaceInvadersInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startDoom()
    self:saveCurrentNote()
    self.currentView = "DOOM"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.doomInstance = PZDoomGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.doomInstance:initialise()
    self:addChild(self.doomInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startRacer()
    self:saveCurrentNote()
    self.currentView = "RACER"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.racerInstance = PZRacerGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.racerInstance:initialise()
    self:addChild(self.racerInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startFlappy()
    self:saveCurrentNote()
    self.currentView = "FLAPPY"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:moveCloseToWindow()
    self.flappyInstance = PZFlappyGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.flappyInstance:initialise()
    self:addChild(self.flappyInstance)
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startBreakout()
    self:saveCurrentNote()
    self.currentView = "BREAKOUT"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.breakoutInstance = PZBreakoutGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.breakoutInstance:initialise()
    self:addChild(self.breakoutInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startAsteroids()
    self:saveCurrentNote()
    self.currentView = "ASTEROIDS"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.asteroidsInstance = PZAsteroidsGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.asteroidsInstance:initialise()
    self:addChild(self.asteroidsInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startFrogger()
    self:saveCurrentNote()
    self.currentView = "FROGGER"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.froggerInstance = PZFroggerGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.froggerInstance:initialise()
    self:addChild(self.froggerInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startMissileCommand()
    self:saveCurrentNote()
    self.currentView = "MISSILE"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.missileInstance = PZMissileCommandGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.missileInstance:initialise()
    self:addChild(self.missileInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startLunarLander()
    self:saveCurrentNote()
    self.currentView = "LANDER"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.landerInstance = PZLunarLanderGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.landerInstance:initialise()
    self:addChild(self.landerInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startCircuitRunner()
    self:saveCurrentNote()
    self.currentView = "CIRCUIT"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.circuitInstance = PZCircuitRunnerGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.circuitInstance:initialise()
    self:addChild(self.circuitInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startMemoryMatch()
    self:saveCurrentNote()
    self.currentView = "MEMORY"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.memoryInstance = PZMemoryMatchGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.memoryInstance:initialise()
    self:addChild(self.memoryInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startStarPilot()
    self:saveCurrentNote()
    self.currentView = "STARPILOT"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.starPilotInstance = PZStarPilotGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.starPilotInstance:initialise()
    self:addChild(self.starPilotInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startCaveRunner()
    self:saveCurrentNote()
    self.currentView = "CAVERUNNER"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.caveRunnerInstance = PZCaveRunnerGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.caveRunnerInstance:initialise()
    self:addChild(self.caveRunnerInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startLightsOut()
    self:saveCurrentNote()
    self.currentView = "LIGHTSOUT"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.lightsOutInstance = PZLightsOutGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.lightsOutInstance:initialise()
    self:addChild(self.lightsOutInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startSignalMatch()
    self:saveCurrentNote()
    self.currentView = "SIGNALMATCH"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.signalMatchInstance = PZSignalMatchGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.signalMatchInstance:initialise()
    self:addChild(self.signalMatchInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startBoxPush()
    self:saveCurrentNote()
    self.currentView = "BOXPUSH"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.boxPushInstance = PZBoxPushGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.boxPushInstance:initialise()
    self:addChild(self.boxPushInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startTileSlide()
    self:saveCurrentNote()
    self.currentView = "TILESLIDE"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.tileSlideInstance = PZTileSlideGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.tileSlideInstance:initialise()
    self:addChild(self.tileSlideInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startPipeLink()
    self:saveCurrentNote()
    self.currentView = "PIPELINK"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.pipeLinkInstance = PZPipeLinkGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.pipeLinkInstance:initialise()
    self:addChild(self.pipeLinkInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startCodeBreaker()
    self:saveCurrentNote()
    self.currentView = "CODEBREAKER"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.codeBreakerInstance = PZCodeBreakerGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.codeBreakerInstance:initialise()
    self:addChild(self.codeBreakerInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startOutbreakOps()
    self:saveCurrentNote()
    self.currentView = "OUTBREAKOPS"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:hideGameLauncherButtons()
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self.outbreakOpsInstance = PZOutbreakOpsGame:new(self.clientX, self.clientY, self.clientW, self.clientH)
    self.outbreakOpsInstance:initialise()
    self:addChild(self.outbreakOpsInstance)
    self:moveCloseToWindow()
    self.closeButton:setVisible(true)
    self.closeButton:bringToTop()
    self:playGameMusic()
    self:updateStartMenuButtons()
end

function target:startNotepad()
    self.activeNotepadKey = nil
    self.activeNotepadName = nil
    self.currentView = "NOTEPAD"
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
    self.backButton:setVisible(true)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:moveCloseToWindow()
    self:setNotepadText(self:getSavedNoteText())
    self.notepadEntry:setVisible(true)
    self.notepadEntry:bringToTop()
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:openDesktopNote(noteKey)
    local note = self:getDesktopNoteByKey(noteKey)
    if not note then
        self.activeNotepadKey = nil
        self.activeNotepadName = nil
        self:startNotepad()
        return
    end
    self.activeNotepadKey = note.key
    self.activeNotepadName = note.name or "Notepad"
    self.currentView = "NOTEPAD"
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
    self.backButton:setVisible(true)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:moveCloseToWindow()
    self:setNotepadText(self:getSavedNoteText())
    self.notepadEntry:setVisible(true)
    self.notepadEntry:bringToTop()
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:startBrowser()
    if not self:requireInternet() then return end
    self:saveCurrentNote()
    self.currentView = "BROWSER"
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
    self.backButton:setVisible(true)
    self.notepadEntry:setVisible(false)
    local data = self:getComputerData()
    if self.browserAddressEntry and data and data.ComputerModBrowserAddress and data.ComputerModBrowserAddress ~= "" then
        if data.ComputerModBrowserAddress == "knoxtv.live" or data.ComputerModBrowserAddress == "knoxradio.live" then
            data.ComputerModBrowserAddress = "knox-weather.net"
            if self.computer then
                ComputerModComputerTypes.transmitData(self.computer)
            end
        end
        self.browserAddressEntry:setText(data.ComputerModBrowserAddress)
    end
    self.browserAddressEntry:setVisible(true)
    self.browserGoButton:setVisible(true)
    if self.browserBackButton then self.browserBackButton:setVisible(true); self.browserBackButton:bringToTop() end
    if self.browserForwardButton then self.browserForwardButton:setVisible(true); self.browserForwardButton:bringToTop() end
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self.closeButton:setVisible(false)
    self:moveCloseToWindow()
    self.browserAddressEntry:bringToTop()
    self.browserGoButton:bringToTop()
    self:navigateBrowser()
    if self.browserDownloadButton then self.browserDownloadButton:bringToTop() end
    if self.downloadSelectButtons then
        for i = 1, #self.downloadSelectButtons do
            self.downloadSelectButtons[i]:bringToTop()
        end
    end
    self:updateBrowserDownloadButton()
    self:updateStartMenuButtons()
end

function target:updateBrowserNavigationButtons()
    local history = self.browserHistory or {}
    local index = tonumber(self.browserHistoryIndex or 0) or 0
    local canBack = index > 1
    local canForward = index > 0 and index < #history
    if self.browserBackButton then
        if self.browserBackButton.setEnable then self.browserBackButton:setEnable(canBack) else self.browserBackButton.enable = canBack end
    end
    if self.browserForwardButton then
        if self.browserForwardButton.setEnable then self.browserForwardButton:setEnable(canForward) else self.browserForwardButton.enable = canForward end
    end
end

function target:recordBrowserHistory(address)
    local value = tostring(address or "")
    if value == "" then return end
    self.browserHistory = self.browserHistory or {}
    local index = math.floor(tonumber(self.browserHistoryIndex or 0) or 0)
    if self.browserHistory[index] == value then
        self:updateBrowserNavigationButtons()
        return
    end
    for i = #self.browserHistory, index + 1, -1 do
        table.remove(self.browserHistory, i)
    end
    self.browserHistory[#self.browserHistory + 1] = value
    if #self.browserHistory > 32 then table.remove(self.browserHistory, 1) end
    self.browserHistoryIndex = #self.browserHistory
    self:updateBrowserNavigationButtons()
end

function target:goBrowserBack()
    local index = math.floor(tonumber(self.browserHistoryIndex or 0) or 0)
    if index <= 1 then return end
    self.browserHistoryIndex = index - 1
    local address = self.browserHistory[self.browserHistoryIndex]
    if self.browserAddressEntry then self.browserAddressEntry:setText(address) end
    self:beginBrowserLoad(address)
    self:updateBrowserNavigationButtons()
end

function target:goBrowserForward()
    local index = math.floor(tonumber(self.browserHistoryIndex or 0) or 0)
    if index <= 0 or index >= #(self.browserHistory or {}) then return end
    self.browserHistoryIndex = index + 1
    local address = self.browserHistory[self.browserHistoryIndex]
    if self.browserAddressEntry then self.browserAddressEntry:setText(address) end
    self:beginBrowserLoad(address)
    self:updateBrowserNavigationButtons()
end

function target:resolveBrowserPage(address)
    local page = browserSites[address] or (ComputerModMagazineSites and ComputerModMagazineSites[address]) or nil
    if not page then
        local lines = {"Suggested addresses:"}
        for i = 1, #publicBrowserSiteOrder do
            lines[#lines + 1] = publicBrowserSiteOrder[i]
        end
        page = {
            title = "Search Results",
            subtitle = "No direct site match for " .. address,
            lines = lines
        }
    end
    return page
end

function target:beginBrowserLoad(address)
    if tostring(self.browserCurrentAddress or "") ~= tostring(address or "") then
        self.downloadGameScrollOffset = 0
    end
    self.browserCurrentAddress = address
    self.browserPage = nil
    self.browserLoading = true
    self.browserLoadProgress = 0
    self.browserPendingAddress = address
    self.browserPendingPage = self:resolveBrowserPage(address)
    self.browserMagazineSelection = nil
    self.browserVideoSelection = nil
    local data = self:getComputerData()
    if data then
        data.ComputerModBrowserAddress = address
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
end

function target:finishBrowserLoad()
    if not self.browserPendingAddress then return end
    self.browserLoading = false
    self.browserLoadProgress = 100
    self.browserPage = self.browserPendingPage or self:resolveBrowserPage(self.browserPendingAddress)
    self.browserCurrentAddress = self.browserPendingAddress
    local address = self.browserPendingAddress
    self.browserPendingAddress = nil
    self.browserPendingPage = nil
    self:updateBrowserMediaButton()
    self:updateBrowserDownloadButton()
    if self.setDownloadControlsVisible then
        self:setDownloadControlsVisible(self.currentView == "BROWSER")
    end
    self:updateBrowserNavigationButtons()
    self:moveCloseToWindow()
    self:updateStartMenuButtons()
    if self.minimizeButton then self.minimizeButton:bringToTop() end
    if self.backButton then self.backButton:bringToTop() end
end

function target:navigateBrowser()
    if not self:requireInternet() then return end
    local address = "knox-weather.net"
    if self.browserAddressEntry and self.browserAddressEntry.getText then
        local typed = self.browserAddressEntry:getText()
        if typed and typed ~= "" then address = string.lower(tostring(typed)) end
    end
    address = string.gsub(address, "^%s+", "")
    address = string.gsub(address, "%s+$", "")
    self:recordBrowserHistory(address)
    self:beginBrowserLoad(address)
end

function target:selectDownloadGame(button)
    if button and button.internal and gameInstallInfo[button.internal] then
        self.downloadSelection = button.internal
    end
end

function target:startSelectedDownload()
    if not self:requireInternet() then return end
    if ComputerModMagazineSites and ComputerModMagazineSites[self.browserCurrentAddress or ""] then
        local site = ComputerModMagazineSites[self.browserCurrentAddress]
        local validMags = self:filterMagazineList(site.magazines or {})
        local magId = self.browserMagazineSelection or validMags[1] or nil
        if not magId then return end
        if self:addDownloadedMagazine(magId) then
            self.fileNoticeText = self:getMagazineDisplayName(magId) .. " " .. tr("saved to Downloads.")
            self.fileNoticeTimer = 150
        else
            self:showError(tr("That archive is already in Downloads."))
        end
        return
    end
    if ComputerModVideoSites and ComputerModVideoSites[self.browserCurrentAddress or ""] then
        local site = ComputerModVideoSites[self.browserCurrentAddress]
        local videos = site and site.videos or {}
        local videoId = self.browserVideoSelection or videos[1] or nil
        if not videoId then return end
        local data = self:getComputerData()
        if not data then return end
        if data.ComputerModActiveDownloadGame or data.ComputerModActiveVideoDownloadId then
            self:showError(tr("A download is already running."))
            return
        end
        if self:isVideoDownloaded(videoId) then
            self:showError(tr("That tape is already in Downloads."))
            return
        end
        data.ComputerModActiveVideoDownloadId = videoId
        data.ComputerModActiveVideoDownloadProgress = 0
        data.ComputerModActiveVideoDownloadLastWorldAge = getComputerWorldAgeHours()
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
            self.downloadLastTransmitMs = getTimestampMs and getTimestampMs() or 0
        end
        self.fileNoticeText = tr("Saving") .. " " .. self:getVideoDisplayName(videoId) .. "..."
        self.fileNoticeTimer = 150
        return
    end
    if self.browserCurrentAddress ~= "knoxshare.bbs" then return end
    local gameId = self.downloadSelection or "pong"
    local data = self:getComputerData()
    if not data or not gameInstallInfo[gameId] then return end
    if data.ComputerModActiveDownloadGame then
        self:showError(tr("A download is already running."))
        return
    end
    if self:isInstallerDownloaded(gameId) then
        self:showError(gameInstallInfo[gameId].label .. " " .. tr("setup is already in Downloads."))
        return
    end
    data.ComputerModActiveDownloadGame = gameId
    data.ComputerModActiveDownloadProgress = 0
    data.ComputerModActiveDownloadLastWorldAge = getComputerWorldAgeHours()
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
        self.downloadLastTransmitMs = getTimestampMs and getTimestampMs() or 0
    end
end

function target:updateDownloadProgress(forceSync)
    local data = self:getComputerData()
    if not data or not data.ComputerModPowerOn then return end
    if not self:isInternetEnabled() then return end
    local hadActiveDownload = data.ComputerModActiveDownloadGame ~= nil or data.ComputerModActiveVideoDownloadId ~= nil
    if not hadActiveDownload then return end
    local worldAge = getComputerWorldAgeHours()
    local finished = false
    local stateChanged = false

    if data.ComputerModActiveDownloadGame then
        local gameId = data.ComputerModActiveDownloadGame
        local info = gameDownloadInfo[gameId]
        if not info then
            data.ComputerModActiveDownloadGame = nil
            data.ComputerModActiveDownloadProgress = nil
            data.ComputerModActiveDownloadLastWorldAge = nil
            stateChanged = true
        else
            local progress = data.ComputerModActiveDownloadProgress or 0
            if worldAge and data.ComputerModActiveDownloadLastWorldAge then
                local elapsedHours = math.max(0, worldAge - data.ComputerModActiveDownloadLastWorldAge)
                progress = progress + elapsedHours * info.speedMBPerTick * 180
            else
                progress = progress + info.speedMBPerTick * getComputerTimeStep()
            end
            data.ComputerModActiveDownloadLastWorldAge = worldAge
            if progress >= info.sizeMB then
                finished = true
                data.ComputerModActiveDownloadGame = nil
                data.ComputerModActiveDownloadProgress = nil
                data.ComputerModActiveDownloadLastWorldAge = nil
                self:addDownloadedInstaller(gameId)
            else
                data.ComputerModActiveDownloadProgress = progress
            end
        end
    end

    if data.ComputerModActiveVideoDownloadId then
        local progress = data.ComputerModActiveVideoDownloadProgress or 0
        if worldAge and data.ComputerModActiveVideoDownloadLastWorldAge then
            local elapsedHours = math.max(0, worldAge - data.ComputerModActiveVideoDownloadLastWorldAge)
            progress = progress + (elapsedHours * 2.0)
        else
            progress = progress + (getComputerTimeStep() / 900)
        end
        data.ComputerModActiveVideoDownloadLastWorldAge = worldAge
        if progress >= 1 then
            local videoId = data.ComputerModActiveVideoDownloadId
            finished = true
            data.ComputerModActiveVideoDownloadId = nil
            data.ComputerModActiveVideoDownloadProgress = nil
            data.ComputerModActiveVideoDownloadLastWorldAge = nil
            self:addDownloadedVideo(videoId)
            self.fileNoticeText = self:getVideoDisplayName(videoId) .. " " .. tr("saved to Downloads.")
            self.fileNoticeTimer = 150
        else
            data.ComputerModActiveVideoDownloadProgress = progress
        end
    end

    local now = getTimestampMs and getTimestampMs() or 0
    local syncDue = forceSync == true or finished or stateChanged
    if not syncDue and now > 0 then
        syncDue = not self.downloadLastTransmitMs or now - self.downloadLastTransmitMs >= 3000
    end
    if self.computer and syncDue then
        self.downloadLastTransmitMs = now
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:getSavedNoteText()
    if not self.computer then return self.lastSavedNoteText or "" end
    local data = self:getComputerData()
    if self.activeNotepadKey and self.activeNotepadKey ~= "" then
        data.ComputerModDesktopNotes = data.ComputerModDesktopNotes or {}
        local note = self:getDesktopNoteByKey(self.activeNotepadKey)
        if note then
            note.text = tostring(note.text or "")
            self.lastSavedNoteText = note.text
            self.activeNotepadName = note.name or self.activeNotepadName
            return note.text
        end
        self.activeNotepadKey = nil
        self.activeNotepadName = nil
    end
    local noteChanged = false
    if data.ComputerModFactoryReset == true then
        if data.ComputerModNotepadText ~= "" then
            data.ComputerModNotepadText = ""
            noteChanged = true
        end
        if data.ComputerModNotepadInitialized ~= true then
            data.ComputerModNotepadInitialized = true
            noteChanged = true
        end
    elseif data.ComputerModNotepadInitialized ~= true then
        if not data.ComputerModNotepadText or data.ComputerModNotepadText == "" then
            data.ComputerModNotepadText = self:generateRoomNoteText()
            noteChanged = true
        end
        data.ComputerModNotepadInitialized = true
        noteChanged = true
    elseif data.ComputerModNotepadText == nil then
        data.ComputerModNotepadText = ""
        noteChanged = true
    end
    if noteChanged and self.computer.transmitModData then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    self.lastSavedNoteText = data.ComputerModNotepadText
    return data.ComputerModNotepadText
end

function target:getCurrentNoteText()
    if not self.notepadEntry then return self.lastSavedNoteText or "" end
    if self.notepadEntry.getInternalText then
        local value = self.notepadEntry:getInternalText()
        if value then return tostring(value) end
    end
    if self.notepadEntry.getText then
        local value = self.notepadEntry:getText()
        if value then return tostring(value) end
    end
    if self.notepadEntry.javaObject and self.notepadEntry.javaObject.getText then
        local value = self.notepadEntry.javaObject:getText()
        if value then return tostring(value) end
    end
    return self.lastSavedNoteText or ""
end

function target:updateNotepadScrollRange(resetToTop)
    local entry = self.notepadEntry
    if not entry or not entry.setScrollHeight then return end
    local text = self:getCurrentNoteText()
    local width = entry.getWidth and entry:getWidth() or entry.width or 0
    local height = entry.getHeight and entry:getHeight() or entry.height or 0
    local scale = math.max(1, tonumber(self.contentScale or self.uiScale or 1) or 1)
    local scrollWidth = math.max(13, math.floor(13 * scale + 0.5))
    local innerWidth = math.max(24, (tonumber(width) or 0) - (tonumber(scrollWidth) or 13) - 12)
    local lineHeight = ComputerModUIText and ComputerModUIText.getLineHeight and ComputerModUIText.getLineHeight(UIFont.Small) or 16
    local visualLines = 0
    for line in string.gmatch(tostring(text or ""):gsub("\r\n", "\n") .. "\n", "(.-)\n") do
        local lineWidth = ComputerModUIText and ComputerModUIText.measureText and ComputerModUIText.measureText(UIFont.Small, line) or string.len(line) * 7
        visualLines = visualLines + math.max(1, math.ceil(lineWidth / innerWidth))
    end
    local contentHeight = math.max(tonumber(height) or 0, visualLines * math.max(1, lineHeight) + 12)
    entry:setScrollHeight(contentHeight)
    if resetToTop and entry.setYScroll then entry:setYScroll(0) end
    if entry.vscroll then
        if entry.vscroll.setWidth then entry.vscroll:setWidth(scrollWidth) end
        if entry.vscroll.setX then entry.vscroll:setX(math.max(0, (tonumber(width) or 0) - (tonumber(scrollWidth) or 13))) end
        if entry.vscroll.setHeight then entry.vscroll:setHeight(tonumber(height) or 0) end
        if entry.vscroll.setVisible then entry.vscroll:setVisible(contentHeight > (tonumber(height) or 0)) end
        if entry.vscroll.bringToTop then entry.vscroll:bringToTop() end
    end
end

function target:setNotepadText(text)
    text = text or ""
    self.lastSavedNoteText = text
    if self.notepadEntry.setText then self.notepadEntry:setText(text) end
    if self.notepadEntry.javaObject and self.notepadEntry.javaObject.SetText then
        self.notepadEntry.javaObject:SetText(text)
    end
    applyEntryColors(self.notepadEntry, {r=0.96, g=0.96, b=0.92, a=1}, {r=0.18, g=0.18, b=0.18, a=1}, {r=0.05, g=0.05, b=0.05, a=1})
    self:updateNotepadScrollRange(true)
end

function target:syncNotepadDataToServer()
    if not isClient or not isClient() or not sendClientCommand then return end
    if not self.computer then return end
    local data = self:getComputerData()
    local square = self.computer.getSquare and self.computer:getSquare() or nil
    local machineId = tostring(data.ComputerModMachineID or "")
    if machineId == "" then return end
    local args = {
        machineId = machineId,
        computerType = tostring(data.ComputerModComputerType or "desktop"),
        driveId = tostring(data.ComputerModDriveID or ""),
        notepadText = tostring(data.ComputerModNotepadText or ""),
        notepadInitialized = data.ComputerModNotepadInitialized == true,
        notepadSeedRepairV1 = data.ComputerModNotepadSeedRepairV1 == true,
        factoryReset = data.ComputerModFactoryReset == true,
        desktopNotes = type(data.ComputerModDesktopNotes) == "table" and data.ComputerModDesktopNotes or {}
    }
    if square then
        args.x = square.getX and square:getX() or nil
        args.y = square.getY and square:getY() or nil
        args.z = square.getZ and square:getZ() or nil
    end
    local player = self.playerObj or (getPlayer and getPlayer() or nil)
    if player then
        sendClientCommand(player, "ComputerModComputerData", "SaveNotes", args)
    end
end

function target:saveCurrentNote()
    if self.currentView ~= "NOTEPAD" then return end
    if not self.computer or not self.notepadEntry then return end
    local text = self:getCurrentNoteText()
    local data = self:getComputerData()
    if self.activeNotepadKey and self.activeNotepadKey ~= "" then
        local note = self:getDesktopNoteByKey(self.activeNotepadKey)
        if note and note.text ~= text then
            note.text = text
            data.ComputerModDesktopNotes = self:getDesktopNotes()
            if text ~= "" then
                data.ComputerModFactoryReset = false
            end
            self.lastSavedNoteText = text
            if self.computer.transmitModData then
                ComputerModComputerTypes.transmitData(self.computer)
            end
            self:syncNotepadDataToServer()
        end
        return
    end
    if data.ComputerModNotepadText ~= text or data.ComputerModNotepadInitialized ~= true then
        data.ComputerModNotepadText = text
        data.ComputerModNotepadInitialized = true
        if text ~= "" then
            data.ComputerModFactoryReset = false
        end
        self.lastSavedNoteText = text
        if self.computer.transmitModData then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        self:syncNotepadDataToServer()
    end
end

end
