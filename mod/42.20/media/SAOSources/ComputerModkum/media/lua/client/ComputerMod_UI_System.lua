function ComputerModInstallUISystem(target)
    local shared = ComputerModUIShared or {}
    local styleRetroButton = shared.styleRetroButton
    local styleIconButton = shared.styleIconButton
    local getGameClockText = shared.getGameClockText
    local getGameDateText = shared.getGameDateText
    local getComputerTimeStep = shared.getComputerTimeStep
    local playComputerUISound = shared.playComputerUISound
    local getComputerWorldAgeHours = shared.getComputerWorldAgeHours
    local addItemWithSavedName = shared.addItemWithSavedName
    local returnDiscToPlayer = shared.returnDiscToPlayer
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
    local textSizeScales = shared.textSizeScales or {0.90, 1.00, 1.15, 1.30, 1.45}
    local uiScaleOptions = shared.uiScaleOptions or {0, 1.00, 1.25, 1.50, 1.75, 2.00, 2.50}
    local gameInstallOrder = shared.gameInstallOrder
    local gameInstallInfo = shared.gameInstallInfo
    local gameDownloadInfo = shared.gameDownloadInfo
    local gameDiscItems = shared.gameDiscItems
    local function getLayoutScale(ui)
        return math.max(1, tonumber(ui and (ui.contentScale or ui.uiScale) or 1) or 1)
    end
    local function uiValue(ui, value)
        return math.floor((tonumber(value) or 0) * getLayoutScale(ui) + 0.5)
    end
    local computerScreenOnSprites = {
        appliances_com_01_72 = "appliances_com_01_76",
        appliances_com_01_73 = "appliances_com_01_77",
        appliances_com_01_74 = "appliances_com_01_78",
        appliances_com_01_75 = "appliances_com_01_79"
    }
    local computerScreenOffSprites = {
        appliances_com_01_76 = "appliances_com_01_72",
        appliances_com_01_77 = "appliances_com_01_73",
        appliances_com_01_78 = "appliances_com_01_74",
        appliances_com_01_79 = "appliances_com_01_75"
    }
    local function getComputerSpriteName(object)
        local sprite = object and object.getSprite and object:getSprite() or nil
        return sprite and sprite.getName and sprite:getName() or nil
    end
    local function syncComputerScreenGlow(object, powerOn)
        if ComputerModScreenGlow and ComputerModScreenGlow.syncObject then
            ComputerModScreenGlow.syncObject(object, powerOn)
        end
    end
    local function sendLocalRecoveryMessage(service, username, recoveryEmail)
        local success, request = ComputerModAccountRecovery.request(service, username, recoveryEmail)
        if not success then return false end
        local appName = service == "chat" and "KnoxChat" or "KnoxMarket"
        local sent, message = ComputerModMail.sendMessage(
            "security@knoxnet.local",
            recoveryEmail,
            appName .. " password reset",
            "A password reset was requested for " .. appName .. " account " .. username .. ". Open this message and select Open reset link to choose a new password."
        )
        if not sent then return false end
        message.recoveryService = service
        message.recoveryRequestId = request.id
        message.recoveryUsername = username
        if ModData.transmit then
            ModData.transmit(ComputerModMail.storeName)
            ModData.transmit(ComputerModAccountRecovery.storeName)
        end
        return true
    end
function target:beginBootSequence()
    self.bootTimer = 0
    self.bootStep = 0
    self.currentView = "BOOTING"
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
    self:setInstallControlsVisible(false)
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:updateMuteMusicButton()
    if not self.muteMusicButton then return end
    self.muteMusicButton:setTitle(self:isMusicMuted() and tr("Music: Off") or tr("Music: On"))
end

function target:updateClockFormatButton()
    if not self.clockFormatButton then return end
    self.clockFormatButton:setTitle(self:is24HourClock() and tr("Clock: 24H") or tr("Clock: 12H"))
end

function target:updateDebugModeButton()
    if not self.debugModeButton then return end
    local player = self.playerObj or getPlayer and getPlayer() or nil
    local enabled = isDebugModeEnabled(player)
    self.debugModeButton:setTitle(tr("Debug mode") .. ": " .. tr(enabled and "Enabled" or "Disabled"))
    if ComputerModDebug and ComputerModDebug.isAdmin and not ComputerModDebug.isAdmin(player) then
        self.debugModeButton.backgroundColor = {r=0.52, g=0.12, b=0.12, a=1}
        self.debugModeButton.borderColor = {r=0.28, g=0.04, b=0.04, a=1}
        self.debugModeButton.textColor = {r=1, g=1, b=1, a=1}
    elseif enabled then
        self.debugModeButton.backgroundColor = {r=0.12, g=0.46, b=0.20, a=1}
        self.debugModeButton.borderColor = {r=0.03, g=0.24, b=0.08, a=1}
        self.debugModeButton.textColor = {r=1, g=1, b=1, a=1}
    else
        self.debugModeButton.backgroundColor = {r=0.75, g=0.75, b=0.75, a=1}
        self.debugModeButton.borderColor = {r=0.18, g=0.18, b=0.18, a=1}
        self.debugModeButton.textColor = {r=0, g=0, b=0, a=1}
    end
end

function target:getTextSizeIndex()
    local data = self:getComputerData()
    local index = data and tonumber(data.ComputerModTextSize or 2) or 2
    index = math.floor(index)
    if index < 1 or index > #textSizeScales then index = 2 end
    return index
end

function target:applyComputerTextSize()
    local scale = textSizeScales[self:getTextSizeIndex()] or 1
    if ComputerModUIText and ComputerModUIText.setUserScale then
        ComputerModUIText.setUserScale(self, scale)
    else
        self.ComputerModUserTextScale = scale
    end
end

function target:updateTextSizeButtons()
    if not self.textSizeButtons then return end
    local selectedIndex = self:getTextSizeIndex()
    for i = 1, #self.textSizeButtons do
        local button = self.textSizeButtons[i]
        if i == selectedIndex then
            button.backgroundColor = {r=0.18, g=0.36, b=0.68, a=1}
            button.textColor = {r=1, g=1, b=1, a=1}
        else
            button.backgroundColor = {r=0.75, g=0.75, b=0.75, a=1}
            button.textColor = {r=0, g=0, b=0, a=1}
        end
    end
end

function target:getUIScaleIndex()
    local data = self:getComputerData()
    local index = data and math.floor(tonumber(data.ComputerModUIScale or 1) or 1) or 1
    if index < 1 or index > #uiScaleOptions then index = 1 end
    return index
end

function target:updateUIScaleButtons()
    if not self.uiScaleButtons then return end
    local selectedIndex = self:getUIScaleIndex()
    for i = 1, #self.uiScaleButtons do
        local button = self.uiScaleButtons[i]
        if i == selectedIndex then
            button.backgroundColor = {r=0.18, g=0.36, b=0.68, a=1}
            button.textColor = {r=1, g=1, b=1, a=1}
        else
            button.backgroundColor = {r=0.75, g=0.75, b=0.75, a=1}
            button.textColor = {r=0, g=0, b=0, a=1}
        end
    end
end

function target:updateGameControlProfileButton()
    if not self.gameControlProfileButton or not ComputerModGameInput then return end
    self.gameControlProfileButton:setTitle(tr("Game controls") .. ": " .. ComputerModGameInput.getLabel(self.playerObj))
end

function target:cycleGameControlProfile()
    if not ComputerModGameInput then return end
    ComputerModGameInput.cycle(self.playerObj or (getPlayer and getPlayer()) or nil)
    self:updateGameControlProfileButton()
end

function target:updateGameMovementLockButton()
    if not self.gameMovementLockButton or not ComputerModGameInput then return end
    local enabled = ComputerModGameInput.isWorldMovementBlocked(self.playerObj)
    self.gameMovementLockButton:setTitle(tr("Block WASD movement") .. ": " .. tr(enabled and "Enabled" or "Disabled"))
end

function target:toggleGameMovementLock()
    if not ComputerModGameInput then return end
    ComputerModGameInput.toggleWorldMovementBlock(self.playerObj or (getPlayer and getPlayer()) or nil)
    self:updateGameMovementLockButton()
end

function target:updateStartMenuButtons()
    local blockedView = self.currentView == "PASSWORD" or self.currentView == "LOCK" or self.currentView == "PASSWORD_HACK" or self.currentView == "NETWORK_TERMINAL" or self.currentView == "NETWORK_REPAIR" or self.currentView == "RESETTING" or self.currentView == "RESET_CONFIRM" or self.currentView == "DISC_WIPING" or self.currentView == "DISC_WIPE_CONFIRM" or self.currentView == "BIOS" or self.currentView == "BOOT_ERROR" or self.currentView == "HARDWARE_ERROR" or self:isFirmwareView()
    local showStartMenu = self.startMenuOpen and self.bootStep >= 3 and not blockedView
    local browserVisible = self.currentView == "BROWSER"
    if self.browserBackButton then self.browserBackButton:setVisible(browserVisible) end
    if self.browserForwardButton then self.browserForwardButton:setVisible(browserVisible) end
    if self.updateBrowserNavigationButtons then self:updateBrowserNavigationButtons() end
    if self.startButton then
        self.startButton:setVisible(self.bootStep >= 3 and not blockedView and self:isOSInstalled())
    end
    self:setDesktopShortcutsVisible(self.currentView == "DESKTOP" and self.bootStep >= 3 and not blockedView and self:isOSInstalled())
    local menuX = self.screenX + uiValue(self, 6)
    local debugNet = isDebugModeEnabled(self.playerObj)
    local menuRows = debugNet and 4 or 3
    local menuTop = self.screenY + self.screenHeight - uiValue(self, 8 + menuRows * 28) - uiValue(self, 26)
    if self.internetOffButton then
        self.internetOffButton:setX(menuX)
        self.internetOffButton:setY(menuTop + uiValue(self, 4))
    end
    if self.internetOnButton then
        self.internetOnButton:setX(menuX)
        self.internetOnButton:setY(menuTop + uiValue(self, 4))
    end
    if self.logOffButton then
        self.logOffButton:setX(menuX)
        self.logOffButton:setY(menuTop + uiValue(self, debugNet and 32 or 4))
    end
    if self.turnOffButton then
        self.turnOffButton:setX(menuX)
        self.turnOffButton:setY(menuTop + uiValue(self, debugNet and 60 or 32))
    end
    if self.settingsButton then
        self.settingsButton:setX(menuX)
        self.settingsButton:setY(menuTop + uiValue(self, debugNet and 88 or 60))
    end
    self.turnOffButton:setVisible(showStartMenu)
    self.settingsButton:setVisible(showStartMenu)
    if self.logOffButton then self.logOffButton:setVisible(showStartMenu) end
    local debugInternetVisible = showStartMenu and isDebugModeEnabled(self.playerObj)
    if self.internetOffButton then self.internetOffButton:setVisible(debugInternetVisible and self:isInternetEnabled()) end
    if self.internetOnButton then self.internetOnButton:setVisible(debugInternetVisible and not self:isInternetEnabled()) end
    self.passwordSettingsButton:setVisible((self.currentView == "SETTINGS" and self.settingsCategory == "security") or self.currentView == "OS_SETUP")
    self.muteMusicButton:setVisible(self.currentView == "SETTINGS" and self.settingsCategory == "system")
    self.clockFormatButton:setVisible(self.currentView == "SETTINGS" and self.settingsCategory == "system")
    self:updateMuteMusicButton()
    self:updateClockFormatButton()
    self:updateDateFormatButton()
    self:updateDebugModeButton()
    self:updateTextSizeButtons()
    if self.minimizeButton then
        local windows = self:getMinimizedWindows()
        self.minimizeButton:setVisible(not self.startMenuOpen and #windows < 3 and self:canMinimizeCurrentView() and not self:isViewMinimized(self.currentView))
    end
    if self.bootBiosButton then
        local bootBiosVisible = ((self.bootStep < 3 and not self:isFirmwareView()) or self.currentView == "BOOT_ERROR") and self:isVisible() and not self:isNetworkTerminal()
        self.bootBiosButton:setVisible(bootBiosVisible)
    end
    if self.hardwareCloseButton then self.hardwareCloseButton:setVisible(self.currentView == "HARDWARE_ERROR") end
    if self.biosBootDiskButton then
        local biosVisible = self.currentView == "BIOS"
        self.biosBootDiskButton:setVisible(biosVisible)
        self.biosBootCDButton:setVisible(biosVisible)
        self.biosWipeDiskButton:setVisible(biosVisible)
        self.biosExitButton:setVisible(biosVisible)
    end
    if self.downloadAllGamesButton then
        self.downloadAllGamesButton:setVisible(self.currentView == "GAMES" and isDebugModeEnabled(self.playerObj))
    end
    if self.currentView ~= "GAMES" and self.hideGameLauncherButtons then
        self:hideGameLauncherButtons()
    end
    self:setSettingsControlsVisible(self.currentView == "SETTINGS" or self.currentView == "OS_SETUP")
    if self.passwordSettingsButton and self.currentView == "OS_SETUP" then
        self.passwordSettingsButton:setVisible(false)
    end
    self:setMailControlsVisible(self.currentView == "MAIL")
    self:setChatControlsVisible(self.currentView == "CHAT")
    self:setFolderEditControlsVisible(self.currentView == "FOLDER_EDIT")
    self:setPostsControlsVisible(self.currentView == "BOARD")
    self:setMarketControlsVisible(self.currentView == "MARKET")
    self:setDownloadControlsVisible(self.currentView == "BROWSER" and (
        self.browserCurrentAddress == "knoxshare.bbs"
        or (ComputerModMagazineSites and ComputerModMagazineSites[self.browserCurrentAddress] ~= nil)
        or (ComputerModVideoSites and ComputerModVideoSites[self.browserCurrentAddress] ~= nil)
    ))
    if self.flappyButton then
        self.flappyButton:setVisible(self.currentView == "GAMES" and self:isGameInstalled("flappy"))
    end
end

function target:toggleStartMenu()
    self.startMenuOpen = not self.startMenuOpen
    if self:isGameView() then
        self:setActiveGamePanelsVisible(not self.startMenuOpen and not self:isViewMinimized(self.currentView))
    end
    if not self.startMenuOpen then self.settingsMenuOpen = false end
    self:updateStartMenuButtons()
end

function target:openSettingsMenu()
    self:openSettingsWindow()
end

function target:toggleMusicMute()
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModMuteMusic = not self:isMusicMuted()
    if self.computer.transmitModData then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    if data.ComputerModMuteMusic and self.gameMusicID then
        if self.stopGameMusic then self:stopGameMusic() end
    elseif not data.ComputerModMuteMusic and self:isGameView() and self.playGameMusic then
        self:playGameMusic()
    end
    self:updateMuteMusicButton()
end

function target:toggleDateFormat()
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModMonthFirstDate = not self:isMonthFirstDate()
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    self:updateDateFormatButton()
end

function target:toggleClockFormat()
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModUse24HourClock = not self:is24HourClock()
    if self.computer.transmitModData then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    self:updateClockFormatButton()
end

function target:toggleComputerDebugMode()
    local player = self.playerObj or getPlayer and getPlayer() or nil
    if not player then return end
    if ComputerModDebug and ComputerModDebug.isAdmin and not ComputerModDebug.isAdmin(player) then
        self:showError(tr("Admin required."))
        self:updateDebugModeButton()
        return
    end
    local enabled = not isDebugModeEnabled(player)
    if isClient and isClient() then
        sendClientCommand(player, "ComputerModNetwork", "SetPlayerDebug", {enabled = enabled})
        return
    end
    if ComputerModDebug and ComputerModDebug.setEnabled and ComputerModDebug.setEnabled(player, enabled) then
        self.fileNoticeText = tr("Debug mode") .. ": " .. tr(enabled and "Enabled" or "Disabled")
        self.fileNoticeTimer = 120
        self:updateStartMenuButtons()
    else
        self:showError(tr("Admin required."))
        self:updateDebugModeButton()
    end
end

function target:handleDebugModeResult(args)
    args = args or {}
    local player = self.playerObj or getPlayer and getPlayer() or nil
    local data = player and player.getModData and player:getModData() or nil
    if data then
        data.ComputerModDebugEnabled = args.success == true and args.enabled == true
    end
    if args.success == true then
        self.fileNoticeText = tr("Debug mode") .. ": " .. tr(args.enabled == true and "Enabled" or "Disabled")
        self.fileNoticeTimer = 120
    else
        self:showError(tr("Admin required."))
    end
    self:updateStartMenuButtons()
end

function target:selectTextSize(button)
    local data = self:getComputerData()
    if not data or not button then return end
    local index = math.floor(tonumber(button.internal or 2) or 2)
    if index < 1 or index > #textSizeScales then index = 2 end
    data.ComputerModTextSize = index
    self:applyComputerTextSize()
    self:updateTextSizeButtons()
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:selectUIScale(button)
    local data = self:getComputerData()
    if not data or not button then return end
    local index = math.floor(tonumber(button.internal or 1) or 1)
    if index < 1 or index > #uiScaleOptions then index = 1 end
    data.ComputerModUIScale = index
    self.fileNoticeText = tr("Interface scale saved. Reopen the computer to apply it.")
    self.fileNoticeTimer = 240
    self:updateUIScaleButtons()
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:isInternetEnabled()
    if ComputerModNetwork and ComputerModNetwork.isInternetEnabled then
        return ComputerModNetwork.isInternetEnabled()
    end
    return true
end

function target:setInternetEnabled(enabled)
    if ComputerModNetwork and ComputerModNetwork.setInternetEnabled then
        if isClient and isClient() then
            sendClientCommand(self.playerObj or getPlayer(), "ComputerModNetwork", "SetInternet", {enabled = enabled == true})
        else
            ComputerModNetwork.setInternetEnabled(enabled == true)
        end
    end
    self.fileNoticeText = enabled and tr("Internet connected.") or tr("Internet disconnected.")
    self.fileNoticeTimer = 120
    if self.playerObj and self.playerObj.Say then
        self.playerObj:Say(self.fileNoticeText)
    end
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:updateStartMenuButtons()
end

function target:isNetworkTerminal()
    local data = self:getComputerData()
    return data and data.ComputerModNetworkTerminal == true
end

function target:getNetworkTerminalId()
    local data = self:getComputerData()
    return data and data.ComputerModNetworkTerminalId or nil
end

function target:getNetworkTerminalLabel()
    local data = self:getComputerData()
    return (data and data.ComputerModNetworkTerminalLabel) or "Network Relay"
end

function target:isNetworkTerminalRepaired()
    local data = self:getComputerData()
    if data and data.ComputerModNetworkRepaired == true then return true end
    local terminalId = self:getNetworkTerminalId()
    local store = ComputerModNetwork and ComputerModNetwork.getStore and ComputerModNetwork.getStore() or nil
    local terminalStore = store and store.terminals and terminalId and store.terminals[terminalId] or nil
    return terminalStore and terminalStore.repaired == true
end

function target:openNetworkTerminal()
    self.currentView = "NETWORK_TERMINAL"
    if self.removeMinimizedView then
        self:removeMinimizedView("NETWORK_TERMINAL")
        self:removeMinimizedView("NETWORK_REPAIR")
    end
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self.fileButton:setVisible(false)
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.gamesMenuButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setResetConfirmControlsVisible(false)
    self:setInstallControlsVisible(false)
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    if self.minimizeButton then self.minimizeButton:setVisible(false) end
    self:updateStartMenuButtons()
end

function target:startNetworkRepair()
    if not self:isNetworkTerminal() then return end
    if self:isInternetEnabled() then
        self:showError(tr("Network is already online."))
        return
    end
    if not self:isNetworkTerminalRepaired() then
        self:showError(tr("Required items missing."))
        return
    end
    if self.removeMinimizedView then
        self:removeMinimizedView("NETWORK_TERMINAL")
        self:removeMinimizedView("NETWORK_REPAIR")
    end
    if self.closeButton then self.closeButton:setVisible(false) end
    if self.minimizeButton then self.minimizeButton:setVisible(false) end
    if self.backButton then self.backButton:setVisible(false) end
    self:completeNetworkRepair()
    self:updateStartMenuButtons()
end

function target:failNetworkRepair()
    self.networkRepairHits = 0
    self.networkRepairLine = 0.08 + (ZombRand(16) / 100)
    self.networkRepairTarget = 0.18 + (ZombRand(64) / 100)
    self.networkRepairSpeed = 0.038
    self.networkRepairErrorTimer = 0
    self:showError(tr("Signal missed. Try again."))
end

function target:completeNetworkRepair()
    local data = self:getComputerData()
    local terminalId = data and data.ComputerModNetworkTerminalId or nil
    local args = {terminalId = terminalId}
    local square = self.computer and self.computer.getSquare and self.computer:getSquare() or nil
    if square then
        args.x = square:getX()
        args.y = square:getY()
        args.z = square:getZ()
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModNetwork", "RepairInternet", args)
        self.fileNoticeText = tr("Repair request sent.")
        self.fileNoticeTimer = 180
    elseif ComputerModNetworkServer and ComputerModNetworkServer.onClientCommand then
        ComputerModNetworkServer.onClientCommand("ComputerModNetwork", "RepairInternet", self.playerObj or getPlayer(), args)
    else
        self:showError(tr("Network relay refused the request."))
    end
    self.networkRepairHits = 0
    self.currentView = "NETWORK_TERMINAL"
    self:updateStartMenuButtons()
end

function target:handleNetworkRepairSpace()
    return self.currentView == "NETWORK_REPAIR"
end

function target:updateNetworkRepair(timeStep)
    if self.currentView ~= "NETWORK_REPAIR" then
        self.networkRepairSpaceWasDown = false
        return
    end
    self.currentView = "NETWORK_TERMINAL"
end

function target:handleNetworkRepairResult(args)
    if args and args.success then
        self.fileNoticeText = args.message or tr("Internet backbone restored.")
        self.fileNoticeTimer = 180
        self.currentView = "NETWORK_TERMINAL"
    else
        self:showError((args and args.message) or tr("Network relay refused the request."))
        self.currentView = "NETWORK_TERMINAL"
    end
    self:updateStartMenuButtons()
end

function target:debugDisconnectInternet()
    if not isDebugModeEnabled(self.playerObj) then return end
    self:setInternetEnabled(false)
end

function target:debugConnectInternet()
    if not isDebugModeEnabled(self.playerObj) then return end
    self:setInternetEnabled(true)
end

function target:requireInternet()
    if self:isInternetEnabled() then return true end
    self:showError(tr("No internet connection."))
    return false
end

function target:saveUserSettings()
    local data = self:getComputerData()
    if not data then return end
    if self.usernameEntry and self.usernameEntry.getText then
        local username = tostring(self.usernameEntry:getText() or "")
        username = string.gsub(username, "^%s+", "")
        username = string.gsub(username, "%s+$", "")
        if username == "" then username = "User" end
        data.ComputerModUsername = username
    end
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:insertNotepadNewLine()
    if self.currentView ~= "NOTEPAD" then return false end
    local text = self:getCurrentNoteText() or ""
    self:setNotepadText(text .. "\n")
    self:saveCurrentNote()
    if self.notepadEntry then
        if self.notepadEntry.setCursorLine then
            pcall(function() self.notepadEntry:setCursorLine(999) end)
        end
        if self.notepadEntry.bringToTop then
            self.notepadEntry:bringToTop()
        end
    end
    return true
end

function target:updateSettingsCategoryLayout()
    local scale = math.max(1, tonumber(self.contentScale or self.uiScale or 1) or 1)
    local function u(value) return math.floor(value * scale + 0.5) end
    if self.currentView == "OS_SETUP" then
        local bodyX = self.screenX + u(8)
        local bodyY = self.screenY + u(8)
        local formX = bodyX + u(168)
        local formW = u(188)
        if self.usernameEntry then
            self.usernameEntry:setX(formX)
            self.usernameEntry:setY(bodyY + u(76))
            self.usernameEntry:setWidth(formW)
        end
        if self.passwordEntry then
            self.passwordEntry:setX(formX)
            self.passwordEntry:setY(bodyY + u(116))
            self.passwordEntry:setWidth(formW)
        end
        if self.installNextButton then
            self.installNextButton:setX(self.screenX + self.screenWidth - u(152))
            self.installNextButton:setY(self.screenY + self.screenHeight - u(38))
            self.installNextButton:setWidth(u(64))
        end
        if self.installCancelButton then
            self.installCancelButton:setX(self.screenX + self.screenWidth - u(80))
            self.installCancelButton:setY(self.screenY + self.screenHeight - u(38))
            self.installCancelButton:setWidth(u(64))
        end
        if self.avatarButtons then
            for i = 1, #self.avatarButtons do
                local button = self.avatarButtons[i]
                button:setX(formX + (i - 1) * u(34))
                button:setY(bodyY + u(170))
                button:setWidth(u(30))
                button:setHeight(u(28))
            end
        end
        return
    end
    local navX = self.clientX + u(12)
    local navW = u(96)
    local panelX = navX + navW + u(26)
    local panelW = self.clientX + self.clientW - panelX - u(12)
    if self.settingsProfileButton then
        self.settingsProfileButton:setX(navX)
        self.settingsProfileButton:setY(self.clientY + u(18))
        self.settingsProfileButton:setWidth(navW)
    end
    if self.settingsSecurityButton then
        self.settingsSecurityButton:setX(navX)
        self.settingsSecurityButton:setY(self.clientY + u(50))
        self.settingsSecurityButton:setWidth(navW)
    end
    if self.settingsSystemButton then
        self.settingsSystemButton:setX(navX)
        self.settingsSystemButton:setY(self.clientY + u(82))
        self.settingsSystemButton:setWidth(navW)
    end
    if self.settingsDisplayButton then
        self.settingsDisplayButton:setX(navX)
        self.settingsDisplayButton:setY(self.clientY + u(114))
        self.settingsDisplayButton:setWidth(navW)
    end
    if self.settingsControlsButton then
        self.settingsControlsButton:setX(navX)
        self.settingsControlsButton:setY(self.clientY + u(146))
        self.settingsControlsButton:setWidth(navW)
    end
    if self.settingsHardwareButton then
        self.settingsHardwareButton:setX(navX)
        self.settingsHardwareButton:setY(self.clientY + u(178))
        self.settingsHardwareButton:setWidth(navW)
    end
    if self.componentDebugButtons then
        for i = 1, #self.componentDebugButtons do
            local button = self.componentDebugButtons[i]
            local partIndex = math.max(0, tonumber(button.internal and button.internal.rowIndex or 1) - 1)
            local actionIndex = (i - 1) % 4
            button:setX(panelX + u(150) + actionIndex * u(34))
            button:setY(self.clientY + u(48) + partIndex * u(39))
            button:setWidth(u(30))
            button:setHeight(u(20))
        end
    end
    if self.gameControlProfileButton then
        self.gameControlProfileButton:setX(panelX)
        self.gameControlProfileButton:setY(self.clientY + u(58))
        self.gameControlProfileButton:setWidth(math.max(u(180), panelW - u(24)))
        self.gameControlProfileButton:setHeight(u(28))
    end
    if self.gameMovementLockButton then
        self.gameMovementLockButton:setX(panelX)
        self.gameMovementLockButton:setY(self.clientY + u(98))
        self.gameMovementLockButton:setWidth(math.max(u(180), panelW - u(24)))
        self.gameMovementLockButton:setHeight(u(28))
    end
    if self.usernameEntry then
        self.usernameEntry:setX(panelX)
        self.usernameEntry:setY(self.clientY + u(52))
        self.usernameEntry:setWidth(math.max(u(118), panelW - u(72)))
    end
    if self.saveUserButton then
        self.saveUserButton:setX(panelX + math.max(u(118), panelW - u(72)) + u(8))
        self.saveUserButton:setY(self.clientY + u(52))
        self.saveUserButton:setWidth(u(58))
    end
    if self.passwordSettingsButton then
        self.passwordSettingsButton:setX(panelX)
        self.passwordSettingsButton:setY(self.clientY + u(92))
        self.passwordSettingsButton:setWidth(u(116))
    end
    if self.dateFormatButton then
        self.dateFormatButton:setX(panelX + u(84))
        self.dateFormatButton:setY(self.clientY + u(146))
        self.dateFormatButton:setWidth(u(120))
    end
    if self.muteMusicButton then
        self.muteMusicButton:setX(panelX)
        self.muteMusicButton:setY(self.clientY + u(96))
        self.muteMusicButton:setWidth(u(104))
    end
    if self.clockFormatButton then
        self.clockFormatButton:setX(panelX + u(116))
        self.clockFormatButton:setY(self.clientY + u(96))
        self.clockFormatButton:setWidth(u(104))
    end
    if self.debugModeButton then
        self.debugModeButton:setX(panelX)
        self.debugModeButton:setY(self.clientY + u(196))
        self.debugModeButton:setWidth(u(184))
    end
    if self.avatarButtons then
        for i = 1, #self.avatarButtons do
            local button = self.avatarButtons[i]
            local col = i - 1
            button:setX(panelX + col * u(32))
            button:setY(self.clientY + u(144))
            button:setWidth(u(30))
            button:setHeight(u(28))
        end
    end
    if self.backgroundButtons then
        for i = 1, #self.backgroundButtons do
            local button = self.backgroundButtons[i]
            local col = i - 1
            button:setX(panelX + col * u(32))
            button:setY(self.clientY + u(76))
            button:setWidth(u(28))
            button:setHeight(u(24))
        end
    end
    if self.textSizeButtons then
        for i = 1, #self.textSizeButtons do
            local button = self.textSizeButtons[i]
            button:setX(panelX + (i - 1) * u(52))
            button:setY(self.clientY + u(144))
            button:setWidth(u(46))
            button:setHeight(u(24))
        end
    end
    if self.uiScaleButtons then
        for i = 1, #self.uiScaleButtons do
            local button = self.uiScaleButtons[i]
            local col = (i - 1) % 4
            local row = math.floor((i - 1) / 4)
            button:setX(panelX + col * u(60))
            button:setY(self.clientY + u(198) + row * u(28))
            button:setWidth(u(54))
            button:setHeight(u(24))
        end
    end
end

function target:showSettingsProfile()
    self.settingsCategory = "profile"
    self:updateSettingsCategoryLayout()
    self:setSettingsControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:showSettingsSecurity()
    self.settingsCategory = "security"
    self:updateSettingsCategoryLayout()
    self:setSettingsControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:showSettingsSystem()
    self.settingsCategory = "system"
    self:updateSettingsCategoryLayout()
    self:setSettingsControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:showSettingsDisplay()
    self.settingsCategory = "display"
    self:updateSettingsCategoryLayout()
    self:setSettingsControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:showSettingsControls()
    self.settingsCategory = "controls"
    self:updateSettingsCategoryLayout()
    self:updateGameControlProfileButton()
    self:updateGameMovementLockButton()
    self:setSettingsControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:showSettingsHardware()
    self.settingsCategory = "hardware"
    self:updateSettingsCategoryLayout()
    self:setSettingsControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:showHardwareFailure(failure)
    self.hardwareFailure = failure or ComputerModComponents.getBootFailure(self:getComputerData())
    self.currentView = "HARDWARE_ERROR"
    self.bootStep = 3
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setResetConfirmControlsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:adjustComponentCondition(button)
    if not button or type(button.internal) ~= "table" or not isDebugModeEnabled(self.playerObj) then return end
    local data = self:getComputerData()
    local partId = button.internal.partId
    local state = data and data.ComputerModComponents and data.ComputerModComponents[partId] or nil
    if type(state) ~= "table" then return end
    local nextCondition = button.internal.value
    if nextCondition == nil then nextCondition = (tonumber(state.condition or 0) or 0) + (tonumber(button.internal.delta or 0) or 0) end
    if isClient and isClient() and ComputerModComponentsClient and ComputerModComponentsClient.requestSetCondition then
        ComputerModComponentsClient.requestSetCondition(self.playerObj, self.computer, partId, nextCondition)
        return
    end
    if ComputerModComponents.setCondition(data, partId, nextCondition) then
        ComputerModComponents.captureDriveData(data)
        if self.computer then ComputerModComputerTypes.transmitData(self.computer) end
    end
end

function target:getBackgroundPaletteIndex()
    local data = self:getComputerData()
    if not data then return 1 end
    local index = tonumber(data.ComputerModBackgroundPalette or 1) or 1
    if index < 1 or index > #backgroundPalettes then
        index = 1
    end
    return index
end

function target:getBackgroundPalette()
    return backgroundPalettes[self:getBackgroundPaletteIndex()] or backgroundPalettes[1]
end

function target:selectBackgroundPalette(button)
    local data = self:getComputerData()
    if not data or not button then return end
    local index = tonumber(button.internal or 1) or 1
    if index < 1 or index > #backgroundPalettes then
        index = 1
    end
    data.ComputerModBackgroundPalette = index
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:getMailMessages()
    local data = self:getComputerData()
    if not data then return {} end
    local activeAddress = self:getActiveMailAddress()
    if activeAddress ~= "" then
        local account = ComputerModMail.getAccount(activeAddress)
        if account and type(account.messages) == "table" then
            return self:ensureMailMessageIds(account.messages)
        end
    end
    if data.ComputerModMailMessages == nil then
        if data.ComputerModMailPlayerCreated then
            data.ComputerModMailMessages = {}
        else
            data.ComputerModMailMessages = self:generateRoomMailMessages()
        end
    end
    return self:ensureMailMessageIds(data.ComputerModMailMessages)
end

function target:ensureMailMessageIds(messages)
    if type(messages) ~= "table" then
        return {}
    end
    local counts = {}
    local nextPositive = 1
    for i = 1, #messages do
        local entry = messages[i]
        if type(entry) == "table" then
            local id = tonumber(entry.id or 0) or 0
            if id ~= 0 then
                counts[id] = (counts[id] or 0) + 1
                if id >= nextPositive then
                    nextPositive = id + 1
                end
            end
        end
    end
    local kept = {}
    for i = 1, #messages do
        local entry = messages[i]
        if type(entry) == "table" then
            local id = tonumber(entry.id or 0) or 0
            if id ~= 0 and counts[id] == 1 and not kept[id] then
                kept[id] = true
            else
                while counts[nextPositive] or kept[nextPositive] do
                    nextPositive = nextPositive + 1
                end
                entry.id = nextPositive
                kept[nextPositive] = true
                nextPositive = nextPositive + 1
            end
        end
    end
    return messages
end

function target:getPlayerAccountPreferences()
    local playerObj = self.playerObj or (self.player and getSpecificPlayer and getSpecificPlayer(self.player)) or nil
    local playerData = playerObj and playerObj.getModData and playerObj:getModData() or nil
    if not playerData then return nil end
    if type(playerData.ComputerModAccountPreferences) ~= "table" then
        playerData.ComputerModAccountPreferences = {}
    end
    return playerData.ComputerModAccountPreferences
end

function target:getPreferredMailAccount()
    local preferences = self:getPlayerAccountPreferences()
    if not preferences then return "", "" end
    return ComputerModMail.normalizeAddress(preferences.mailAddress or ""), ComputerModMail.trim(preferences.mailPassword or "")
end

function target:rememberPreferredMailAccount(address, password)
    address = ComputerModMail.normalizeAddress(address or "")
    password = ComputerModMail.trim(password or "")
    if not ComputerModMail.isValidAddress(address) or password == "" then return false end
    local preferences = self:getPlayerAccountPreferences()
    if not preferences then return false end
    preferences.mailAddress = address
    preferences.mailPassword = password
    local playerObj = self.playerObj or (self.player and getSpecificPlayer and getSpecificPlayer(self.player)) or nil
    if playerObj and playerObj.transmitModData then
        playerObj:transmitModData()
    end
    return true
end

function target:clearPreferredMailAccount()
    local preferences = self:getPlayerAccountPreferences()
    if not preferences then return end
    preferences.mailAddress = nil
    preferences.mailPassword = nil
    local playerObj = self.playerObj or (self.player and getSpecificPlayer and getSpecificPlayer(self.player)) or nil
    if playerObj and playerObj.transmitModData then
        playerObj:transmitModData()
    end
end

function target:restorePreferredMailSession()
    local address, password = self:getPreferredMailAccount()
    if not ComputerModMail.isValidAddress(address) or password == "" then return false end
    if isClient and isClient() then
        self.preferredMailLoginPending = true
        self.preferredMailLoginPassword = password
        self:setMailSessionAddress(address, true)
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "Login", {address = address, password = password})
        return true
    end
    local success = ComputerModMail.login(address, password)
    if not success then
        self:clearPreferredMailAccount()
        return false
    end
    self:setMailSessionAddress(address, true)
    return true
end

function target:getActiveMailAddress()
    local data = self:getComputerData()
    if not data then return "" end
    if self.mailSessionLoggedOut == true then return "" end
    local active = ComputerModMail.normalizeAddress(self.mailSessionAddress or "")
    if active ~= "" then return active end
    if data.ComputerModMailPlayerCreated ~= true and data.ComputerModMailLoggedIn == true then
        return ComputerModMail.normalizeAddress(data.ComputerModMailAddress or "")
    end
    return ""
end

function target:getMailAccountData(address)
    return ComputerModMail.getAccount(address or self:getActiveMailAddress())
end

function target:setMailSessionAddress(address, keepLoggedIn)
    local normalized = address and ComputerModMail.normalizeAddress(address) or ""
    self.mailSessionAddress = keepLoggedIn == true and normalized ~= "" and normalized or nil
    self.mailSessionLoggedOut = keepLoggedIn ~= true
end

function target:hasMailAccount()
    local data = self:getComputerData()
    return data and data.ComputerModMailAddress and data.ComputerModMailAddress ~= "" and data.ComputerModMailPassword and data.ComputerModMailPassword ~= ""
end

function target:isMailLoggedIn()
    return self:getActiveMailAddress() ~= ""
end

function target:generateRoomMailMessages()
    local roomName = self:getComputerRoomName()
    local hintSite = ComputerModSecretSiteHints and ComputerModSecretSiteHints[ZombRand(#ComputerModSecretSiteHints) + 1] or "sparkwork.shop"
    local seed = tostring((self:getComputerData() and self:getComputerData().ComputerModMachineID) or ZombRand(9999))
    local hintBodies = {
        "I found the missing scan on " .. hintSite .. ". Print it only if you need it.",
        "The paper copy never came back, but " .. hintSite .. " still has the scan.",
        "Leave the old board address alone unless you need that recipe: " .. hintSite,
        "That address from the back room still works: " .. hintSite,
        "If anyone asks about the binder, say the backup is on " .. hintSite .. ".",
        "The photocopy is unreadable. Try " .. hintSite .. " from this machine."
    }
    local generalPool = {
        {id = -1, from = "ops@county.local", to = "", subject = "Shift Update", body = "Printer toner is low again. Check the supply cabinet before noon.\nRef " .. string.sub(seed, -4), stamp = ""},
        {id = -2, from = "archive@county.local", to = "", subject = "Old Link", body = hintBodies[ZombRand(#hintBodies) + 1] .. "\nMachine " .. string.sub(seed, 1, 6), stamp = ""},
        {id = -3, from = "itdesk@county.local", to = "", subject = "Login Reminder", body = "Do not leave the machine signed in overnight.\nDesk tag " .. tostring(ZombRand(10, 99)), stamp = ""},
        {id = -4, from = "clerk@county.local", to = "", subject = "Supply Cabinet", body = "Someone borrowed the spare mouse and never signed it out. Check the top drawer first.", stamp = ""},
        {id = -5, from = "maintenance@county.local", to = "", subject = "Power Flicker", body = "If the monitor snaps off again, leave it for morning. The wall outlet is not worth arguing with.", stamp = ""}
    }
    local mails = {}
    while #mails < 3 and #generalPool > 0 do
        local index = ZombRand(#generalPool) + 1
        mails[#mails + 1] = generalPool[index]
        table.remove(generalPool, index)
    end
    if string.find(roomName, "police") then
        local pool = {
            {id = -1, from = "dispatch@county.local", to = "", subject = "Evidence Intake", body = "Two new boxes are waiting in storage. Incident logs still need filing.", stamp = ""},
            {id = -1, from = "records@county.local", to = "", subject = "Case Numbers", body = "The south lot report is missing a page. Ask patrol before sending copies downtown.", stamp = ""},
            {id = -1, from = "desk@county.local", to = "", subject = "Radio Log", body = "Night shift wrote three noise calls under the wrong block. Please fix before noon.", stamp = ""}
        }
        mails[1] = pool[ZombRand(#pool) + 1]
    elseif string.find(roomName, "school") or string.find(roomName, "class") then
        local pool = {
            {id = -1, from = "principal@school.local", to = "", subject = "Classroom Memo", body = "Library magazines were boxed by subject. One student wrote down " .. hintSite .. " on the chalk tray.", stamp = ""},
            {id = -1, from = "library@school.local", to = "", subject = "Overdue Cart", body = "The AV cart came back with no cable. Please check the science room.", stamp = ""},
            {id = -1, from = "office@school.local", to = "", subject = "Attendance Sheets", body = "Send morning attendance before the bell. The dot matrix printer is behaving today.", stamp = ""}
        }
        mails[1] = pool[ZombRand(#pool) + 1]
    elseif string.find(roomName, "medical") then
        local pool = {
            {id = -1, from = "lab@clinic.local", to = "", subject = "Lab Supply", body = "Front office asked for the herbal digest again. Check " .. hintSite .. " if the print copy is missing.", stamp = ""},
            {id = -1, from = "nurse@clinic.local", to = "", subject = "Cold Cabinet", body = "The sample fridge was left open for ten minutes. Log it before shift change.", stamp = ""},
            {id = -1, from = "pharmacy@clinic.local", to = "", subject = "Late Delivery", body = "Painkiller crate is delayed. Count what is left and update the sheet.", stamp = ""}
        }
        mails[1] = pool[ZombRand(#pool) + 1]
    elseif string.find(roomName, "store") or string.find(roomName, "market") then
        local pool = {
            {id = -1, from = "manager@shop.local", to = "", subject = "Register Count", body = "Drawer two was short again. Check receipts before closing.", stamp = ""},
            {id = -1, from = "stock@shop.local", to = "", subject = "Back Room", body = "Canned goods are mixed with cleaning supplies. Move them before inspection.", stamp = ""},
            {id = -1, from = "supplier@shop.local", to = "", subject = "Truck Delay", body = "Paper towels and batteries will arrive late. Update the front board.", stamp = ""}
        }
        mails[1] = pool[ZombRand(#pool) + 1]
    elseif string.find(roomName, "kitchen") or string.find(roomName, "restaurant") or string.find(roomName, "cafe") then
        local pool = {
            {id = -1, from = "chef@diner.local", to = "", subject = "Prep List", body = "Slice tomatoes before lunch rush. Also stop using the office disks as coasters.", stamp = ""},
            {id = -1, from = "orders@diner.local", to = "", subject = "Supplier Call", body = "Bread supplier wants confirmation before eleven. Leave a note if line is busy.", stamp = ""},
            {id = -1, from = "front@diner.local", to = "", subject = "Coffee", body = "The good filters are hidden behind the flour. Do not tell night shift.", stamp = ""}
        }
        mails[1] = pool[ZombRand(#pool) + 1]
    end
    if ComputerModLocalization then
        for i = 1, #mails do ComputerModLocalization.localizeMail(mails[i]) end
    end
    return mails
end

function target:syncComputerMailAccount()
    local data = self:getComputerData()
    if not data or not data.ComputerModMailAddress or data.ComputerModMailAddress == "" then return end
    if data.ComputerModMailPlayerCreated == true then return end
    local computerAddress = ComputerModMail.normalizeAddress(data.ComputerModMailAddress)
    local activeAddress = ComputerModMail.normalizeAddress(data.ComputerModMailSessionAddress or "")
    local args = {
        address = computerAddress,
        password = tostring(data.ComputerModMailPassword or ""),
        messages = data.ComputerModMailMessages or self:generateRoomMailMessages(),
        authenticate = data.ComputerModMailLoggedIn == true
    }
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "EnsureAccount", args)
    else
        local created = nil
        local ok = nil
        ok, created = ComputerModMail.ensureAccount(args.address, args.password, args.messages)
        if ok and ModData.transmit then
            ModData.transmit(ComputerModMail.storeName)
        end
    end
end

function target:handleMailPrimaryAction()
    local data = self:getComputerData()
    if not data or not self.mailAddressEntry or not self.mailPasswordEntry then return end
    local address = ComputerModMail.normalizeAddress(self.mailAddressEntry:getText() or "")
    local password = ComputerModMail.trim(self.mailPasswordEntry:getText() or "")
    if address == "" or password == "" then
        self:showError(tr("Enter an email and password."))
        return
    end
    if not ComputerModMail.isValidAddress(address) then
        self:showError(tr("Enter a full address like user@server."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "CreateAccount", {address = address, password = password})
        return
    end
    local success, result = ComputerModMail.createAccount(address, password)
    if not success then
        self:showError(result == "exists" and tr("That address already exists.") or tr("Mail account could not be created."))
        return
    end
    self:rememberPreferredMailAccount(address, password)
    if ComputerModSPActivity then
        ComputerModSPActivity.registerMailAccount(result, self.playerObj)
        ComputerModSPActivity.update()
    end
    self:setMailSessionAddress(address, true)
    self.mailComposeMode = false
    self.mailSelectedMessageId = nil
    if ModData.transmit then
        ModData.transmit(ComputerModMail.storeName)
    end
    self.fileNoticeText = tr("Mailbox created.")
    self.fileNoticeTimer = 120
    self:setMailControlsVisible(true)
end

function target:handleMailSecondaryAction()
    local data = self:getComputerData()
    if not data or not self.mailAddressEntry or not self.mailPasswordEntry then return end
    local address = ComputerModMail.normalizeAddress(self.mailAddressEntry:getText() or "")
    local password = ComputerModMail.trim(self.mailPasswordEntry:getText() or "")
    if not ComputerModMail.isValidAddress(address) or password == "" then
        self:showError(tr("Enter the full email and password."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "Login", {address = address, password = password})
        return
    end
    local success, account = ComputerModMail.login(address, password)
    if success then
        self:rememberPreferredMailAccount(address, password)
        if data.ComputerModMailPlayerCreated == true and ComputerModMail.normalizeAddress(data.ComputerModMailAddress or "") == address and ComputerModSPActivity then
            ComputerModSPActivity.registerMailAccount(account, self.playerObj)
            ComputerModSPActivity.update()
        end
        self:setMailSessionAddress(address, true)
        self.fileNoticeText = ""
        self.fileNoticeTimer = 0
        self.mailComposeMode = false
        self.mailSelectedMessageId = nil
        self:setMailControlsVisible(true)
    else
        self:showError(tr("Mail login failed."))
    end
end

function target:logOutMail()
    if isClient and isClient() and sendClientCommand then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "Logout", {})
    end
    self:setMailSessionAddress(nil, false)
    self.mailComposeMode = false
    self.mailSelectedMessageId = nil
    if self.mailPasswordEntry then
        self.mailPasswordEntry:setText("")
    end
    self:setMailControlsVisible(true)
end

function target:getSelectedMailMessage()
    local messages = self:getMailMessages()
    if #messages == 0 then
        self.mailSelectedMessageId = nil
        return nil
    end
    local selectedId = tonumber(self.mailSelectedMessageId or 0) or 0
    for i = 1, #messages do
        if tonumber(messages[i].id or 0) == selectedId then
            return messages[i]
        end
    end
    self.mailSelectedMessageId = tonumber(messages[1].id or 0) or 0
    return messages[1]
end

function target:selectMailMessageByIndex(index)
    local messages = self:getMailMessages()
    local entry = messages[index]
    if not entry then return end
    self.mailSelectedMessageId = tonumber(entry.id or 0) or 0
end

function target:openAccountPasswordReset(service, username, requestId)
    self.accountRecoveryService = nil
    self.accountRecoveryUsername = nil
    self.accountRecoveryRequestId = nil
    self.fileNoticeText = ""
    self.fileNoticeTimer = 0
    if service == "chat" then
        self:startChat()
        if self.currentView ~= "CHAT" then return end
        self.accountRecoveryService = "chat"
        self.accountRecoveryUsername = ComputerModChat.normalizeUsername(username)
        self.accountRecoveryRequestId = tostring(requestId or "")
        if self.chatUserEntry then self.chatUserEntry:setText(self.accountRecoveryUsername) end
        if self.chatPasswordEntry then self.chatPasswordEntry:setText("") end
        self:setChatControlsVisible(true)
    elseif service == "market" then
        self:startMarket()
        if self.currentView ~= "MARKET" then return end
        self.accountRecoveryService = "market"
        self.accountRecoveryUsername = ComputerModMarket.normalizeUsername(username)
        self.accountRecoveryRequestId = tostring(requestId or "")
        if self.marketUserEntry then self.marketUserEntry:setText(self.accountRecoveryUsername) end
        if self.marketPasswordEntry then self.marketPasswordEntry:setText("") end
        self:setMarketControlsVisible(true)
    end
end

function target:openSelectedMailRecoveryLink()
    local selected = self:getSelectedMailMessage()
    local address = self:getActiveMailAddress()
    if not selected or not selected.recoveryRequestId or address == "" then
        self:showError(tr("Password reset link expired."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "OpenRecoveryLink", {
            address = address,
            messageId = tonumber(selected.id or 0) or 0
        })
        return
    end
    local success, request = ComputerModAccountRecovery.authorize(self.playerObj or getPlayer(), selected.recoveryRequestId, address)
    if not success then
        self:showError(tr("Password reset link expired."))
        return
    end
    self:openAccountPasswordReset(request.service, request.username, request.id)
end

function target:startMailCompose()
    self.mailComposeMode = true
    if self.mailToEntry then self.mailToEntry:setText("") end
    if self.mailSubjectEntry then self.mailSubjectEntry:setText("") end
    if self.mailBodyEntry then self.mailBodyEntry:setText("") end
    self:setMailControlsVisible(true)
end

function target:cancelMailCompose()
    self.mailComposeMode = false
    if self.mailToEntry then self.mailToEntry:setText("") end
    if self.mailSubjectEntry then self.mailSubjectEntry:setText("") end
    if self.mailBodyEntry then self.mailBodyEntry:setText("") end
    self:setMailControlsVisible(true)
end

function target:replyToSelectedMail()
    local selected = self:getSelectedMailMessage()
    if not selected then
        self:showError(tr("Select a mail first."))
        return
    end
    self.mailComposeMode = true
    if self.mailToEntry then self.mailToEntry:setText(tostring(selected.from or "")) end
    local replySubject = tostring(selected.subject or "Mail")
    if string.sub(string.lower(replySubject), 1, 4) ~= "re: " then
        replySubject = "Re: " .. replySubject
    end
    if self.mailSubjectEntry then self.mailSubjectEntry:setText(replySubject) end
    if self.mailBodyEntry then self.mailBodyEntry:setText("\n\n---\n" .. tostring(selected.body or "")) end
    self:setMailControlsVisible(true)
end

function target:deleteSelectedMail()
    local selected = self:getSelectedMailMessage()
    local activeAddress = self:getActiveMailAddress()
    if not selected or activeAddress == "" then
        self:showError(tr("Select a mail first."))
        return
    end
    local messageId = tonumber(selected.id or 0) or 0
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "DeleteMessage", {address = activeAddress, messageId = messageId})
        return
    end
    if ComputerModMail.deleteMessage(activeAddress, messageId) then
        self.mailSelectedMessageId = nil
        self.fileNoticeText = tr("Mail deleted.")
        self.fileNoticeTimer = 120
        if ModData.transmit then
            ModData.transmit(ComputerModMail.storeName)
        end
        self:setMailControlsVisible(true)
    else
        self:showError(tr("Mail could not be deleted."))
    end
end

function target:sendComposedMail()
    local fromAddress = self:getActiveMailAddress()
    if fromAddress == "" then
        self:showError(tr("Sign in first."))
        return
    end
    local toAddress = ComputerModMail.normalizeAddress(self.mailToEntry and self.mailToEntry:getText() or "")
    local subject = ComputerModMail.trim(self.mailSubjectEntry and self.mailSubjectEntry:getText() or "")
    local body = tostring(self.mailBodyEntry and self.mailBodyEntry:getText() or "")
    if not ComputerModMail.isValidAddress(toAddress) then
        self:showError(tr("Enter a full target address."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMail", "SendMessage", {
            fromAddress = fromAddress,
            toAddress = toAddress,
            subject = subject,
            body = body
        })
        return
    end
    local success, reason = ComputerModMail.sendMessage(fromAddress, toAddress, subject, body)
    if success then
        self.mailComposeMode = false
        if self.mailToEntry then self.mailToEntry:setText("") end
        if self.mailSubjectEntry then self.mailSubjectEntry:setText("") end
        if self.mailBodyEntry then self.mailBodyEntry:setText("") end
        self.fileNoticeText = tr("Mail sent.")
        self.fileNoticeTimer = 120
        if ModData.transmit then
            ModData.transmit(ComputerModMail.storeName)
        end
        self:setMailControlsVisible(true)
    else
        self:showError(reason == "unknown" and tr("That mailbox does not exist.") or tr("Mail could not be sent."))
    end
end

function target:handleMailServerCommand(command, args)
    args = args or {}
    if command == "CreateResult" then
        if args.success then
            local createdAddress = ComputerModMail.normalizeAddress(args.address or "")
            local createdPassword = ComputerModMail.trim(self.mailPasswordEntry and self.mailPasswordEntry:getText() or "")
            self:rememberPreferredMailAccount(createdAddress, createdPassword)
            self:setMailSessionAddress(createdAddress, true)
            self.mailComposeMode = false
            self.mailSelectedMessageId = nil
            self.fileNoticeText = tr("Mailbox created.")
            self.fileNoticeTimer = 120
            self:setMailControlsVisible(true)
        else
            self:showError(args.reason == "exists" and tr("That address already exists.") or tr("Mail account could not be created."))
        end
        return
    end
    if command == "LoginResult" then
        if args.success then
            local loginPassword = ComputerModMail.trim(self.mailPasswordEntry and self.mailPasswordEntry:getText() or "")
            if loginPassword == "" and self.preferredMailLoginPending then
                loginPassword = ComputerModMail.trim(self.preferredMailLoginPassword or "")
            end
            self:rememberPreferredMailAccount(args.address, loginPassword)
            self:setMailSessionAddress(args.address, true)
            self.mailComposeMode = false
            self.mailSelectedMessageId = nil
            self.fileNoticeText = ""
            self.fileNoticeTimer = 0
            self:setMailControlsVisible(true)
        else
            if self.preferredMailLoginPending then
                self:setMailSessionAddress(nil, false)
                self:clearPreferredMailAccount()
            end
            self:showError(tr("Mail login failed."))
        end
        self.preferredMailLoginPending = false
        self.preferredMailLoginPassword = nil
        return
    end
    if command == "SendResult" then
        if args.success then
            self.mailComposeMode = false
            if self.mailToEntry then self.mailToEntry:setText("") end
            if self.mailSubjectEntry then self.mailSubjectEntry:setText("") end
            if self.mailBodyEntry then self.mailBodyEntry:setText("") end
            self.fileNoticeText = tr("Mail sent.")
            self.fileNoticeTimer = 120
            self:setMailControlsVisible(true)
        elseif args.reason == "auth" then
            self:setMailSessionAddress(nil, false)
            self:showError(tr("Sign in first."))
            self:setMailControlsVisible(true)
        else
            self:showError(args.reason == "unknown" and tr("That mailbox does not exist.") or tr("Mail could not be sent."))
        end
        return
    end
    if command == "DeleteResult" then
        if args.success then
            self.mailSelectedMessageId = nil
            self.fileNoticeText = tr("Mail deleted.")
            self.fileNoticeTimer = 120
        elseif args.reason == "auth" then
            self:setMailSessionAddress(nil, false)
            self:showError(tr("Sign in first."))
        else
            self:showError(tr("Mail could not be deleted."))
        end
        self:setMailControlsVisible(true)
        return
    end
    if command == "RecoveryLinkResult" then
        if args.success then
            self:openAccountPasswordReset(args.service, args.username, args.requestId)
        else
            self:showError(args.reason == "auth" and tr("Sign in first.") or tr("Password reset link expired."))
        end
        return
    end
end

function target:getActiveChatUser()
    local data = self:getComputerData()
    if not data or data.ComputerModChatLoggedIn ~= true then return "" end
    return ComputerModChat.normalizeUsername(data.ComputerModChatSessionUser or "")
end

function target:setChatSessionUser(username, keepLoggedIn)
    local data = self:getComputerData()
    if not data then return end
    local normalized = ComputerModChat.normalizeUsername(username or "")
    data.ComputerModChatSessionUser = normalized ~= "" and normalized or nil
    data.ComputerModChatLoggedIn = keepLoggedIn == true and normalized ~= ""
    if normalized ~= "" then
        data.ComputerModChatUsername = normalized
    end
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:isChatLoggedIn()
    return self:getActiveChatUser() ~= ""
end

function target:getChatAccountData(username)
    return ComputerModChat.getAccount(username or self:getActiveChatUser())
end

function target:getChatContacts()
    local account = self:getChatAccountData()
    local contacts = {}
    if not account or type(account.contacts) ~= "table" then
        return contacts
    end
    for username, displayName in pairs(account.contacts) do
        contacts[#contacts + 1] = {username = tostring(username), displayName = tostring(displayName or username)}
    end
    table.sort(contacts, function(a, b) return string.lower(a.displayName) < string.lower(b.displayName) end)
    return contacts
end

function target:getChatRequests()
    local account = self:getChatAccountData()
    local requests = {}
    if not account or type(account.requests) ~= "table" then
        return requests
    end
    for i = 1, #account.requests do
        local request = account.requests[i]
        requests[#requests + 1] = {
            from = tostring(request.from or ""),
            displayName = tostring(request.displayName or request.from or ""),
            stamp = tostring(request.stamp or "")
        }
    end
    return requests
end

function target:getSelectedChatPartner()
    if self.chatSelectedRequestUser and self:getSelectedChatRequest() then
        return nil
    end
    local contacts = self:getChatContacts()
    if #contacts == 0 then
        self.chatSelectedUser = nil
        return nil
    end
    for i = 1, #contacts do
        if contacts[i].username == self.chatSelectedUser then
            return contacts[i]
        end
    end
    self.chatSelectedUser = contacts[1].username
    return contacts[1]
end

function target:getSelectedChatRequest()
    local requests = self:getChatRequests()
    if #requests == 0 then
        self.chatSelectedRequestUser = nil
        return nil
    end
    for i = 1, #requests do
        if requests[i].from == self.chatSelectedRequestUser then
            return requests[i]
        end
    end
    self.chatSelectedRequestUser = requests[1].from
    return requests[1]
end

function target:getChatConversation()
    local account = self:getChatAccountData()
    local partner = self:getSelectedChatPartner()
    if not account or not partner then
        return {}
    end
    return ComputerModChat.getConversation(account, partner.username)
end

function target:handleChatPrimaryAction()
    local data = self:getComputerData()
    if not data or not self.chatUserEntry or not self.chatPasswordEntry then return end
    local username = ComputerModChat.trim(self.chatUserEntry:getText() or "")
    local password = ComputerModChat.trim(self.chatPasswordEntry:getText() or "")
    local recoveryEmail = ComputerModMail.normalizeAddress(self.chatRecoveryEmailEntry and self.chatRecoveryEmailEntry:getText() or "")
    if username == "" or password == "" then
        self:showError(tr("Enter a user name and password."))
        return
    end
    if not ComputerModChat.isValidUsername(username) then
        self:showError(tr("Use 3-32 letters, numbers, dots, dashes or underscores."))
        return
    end
    if recoveryEmail ~= "" and not ComputerModMail.isValidAddress(recoveryEmail) then
        self:showError(tr("Enter a full address like user@server."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "CreateAccount", {username = username, password = password, recoveryEmail = recoveryEmail})
        return
    end
    local success, result = ComputerModChat.createAccount(username, password, recoveryEmail, recoveryEmail == "")
    if success then
        data.ComputerModChatUsername = ComputerModChat.normalizeUsername(username)
        if ComputerModSPActivity then
            ComputerModSPActivity.registerChatAccount(result)
            ComputerModSPActivity.update()
        end
        self:setChatSessionUser(username, true)
        self.chatRequestMode = false
        self.fileNoticeText = tr("Account created.")
        self.fileNoticeTimer = 120
        if ModData.transmit then
            ModData.transmit(ComputerModChat.storeName)
        end
        self:setChatControlsVisible(true)
    else
        if result == "exists" then
            self:showError(tr("That user name already exists."))
        elseif result == "mail" then
            self:showError(tr("That mailbox does not exist."))
        else
            self:showError(tr("Chat account could not be created."))
        end
    end
end

function target:requestChatPasswordReset()
    local username = ComputerModChat.normalizeUsername(self.chatUserEntry and self.chatUserEntry:getText() or "")
    if not ComputerModChat.isValidUsername(username) then
        self:showError(tr("Enter a valid user name and password."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "RequestPasswordReset", {username = username})
        return
    end
    local account = ComputerModChat.getAccount(username)
    if not account or not account.recoveryEmail or not ComputerModMail.getAccount(account.recoveryEmail) or not sendLocalRecoveryMessage("chat", username, account.recoveryEmail) then
        self:showError(tr("Password recovery is unavailable for this account."))
        return
    end
    self.fileNoticeText = tr("Password reset link sent.")
    self.fileNoticeTimer = 180
end

function target:submitChatPasswordReset()
    if self.accountRecoveryService ~= "chat" then return end
    local password = ComputerModChat.trim(self.chatPasswordEntry and self.chatPasswordEntry:getText() or "")
    if password == "" then
        self:showError(tr("Enter a user name and password."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "ResetPassword", {
            requestId = self.accountRecoveryRequestId,
            password = password
        })
        return
    end
    local success, username = ComputerModAccountRecovery.consume(self.playerObj or getPlayer(), self.accountRecoveryRequestId, "chat")
    local account = success and ComputerModChat.getAccount(username) or nil
    if not account then
        self:showError(tr("Password reset link expired."))
        return
    end
    account.password = password
    self.accountRecoveryService = nil
    self.accountRecoveryUsername = nil
    self.accountRecoveryRequestId = nil
    self:setChatSessionUser(username, true)
    if ComputerModSPActivity then ComputerModSPActivity.registerChatAccount(account) end
    if ModData.transmit then
        ModData.transmit(ComputerModChat.storeName)
        ModData.transmit(ComputerModAccountRecovery.storeName)
    end
    self.fileNoticeText = tr("Password updated.")
    self.fileNoticeTimer = 180
    self:setChatControlsVisible(true)
end

function target:handleChatSecondaryAction()
    if not self.chatUserEntry or not self.chatPasswordEntry then return end
    local username = ComputerModChat.trim(self.chatUserEntry:getText() or "")
    local password = ComputerModChat.trim(self.chatPasswordEntry:getText() or "")
    if not ComputerModChat.isValidUsername(username) or password == "" then
        self:showError(tr("Enter a valid user name and password."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "Login", {username = username, password = password})
        return
    end
    local success, account = ComputerModChat.login(username, password)
    if success then
        local data = self:getComputerData()
        if data then
            data.ComputerModChatUsername = ComputerModChat.normalizeUsername(username)
        end
        if ComputerModSPActivity then
            ComputerModSPActivity.registerChatAccount(account)
            ComputerModSPActivity.update()
        end
        self:setChatSessionUser(username, true)
        self.fileNoticeText = ""
        self.fileNoticeTimer = 0
        self.chatRequestMode = false
        self:setChatControlsVisible(true)
    else
        self:showError(tr("Chat login failed."))
    end
end

function target:logOutChat()
    if isClient and isClient() and sendClientCommand then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "Logout", {})
    end
    self:setChatSessionUser(nil, false)
    self.chatSelectedUser = nil
    self.chatSelectedRequestUser = nil
    self.chatRequestMode = false
    self.chatMessageScrollOffset = nil
    if self.chatPasswordEntry then
        self.chatPasswordEntry:setText("")
    end
    if self.chatMessageEntry then
        self.chatMessageEntry:setText("")
    end
    self:setChatControlsVisible(true)
end

function target:startChatRequestMode()
    self.chatRequestMode = true
    self.chatSelectedRequestUser = nil
    self.chatMessageScrollOffset = nil
    if self.chatRequestEntry then
        self.chatRequestEntry:setText("")
    end
    self:setChatControlsVisible(true)
end

function target:cancelChatRequestMode()
    self.chatRequestMode = false
    if self.chatRequestEntry then
        self.chatRequestEntry:setText("")
    end
    self:setChatControlsVisible(true)
end

function target:selectChatContactByIndex(index)
    local contacts = self:getChatContacts()
    local entry = contacts[index]
    if not entry then return end
    self.chatSelectedUser = entry.username
    self.chatSelectedRequestUser = nil
    self.chatExpandedMessageIndex = nil
    self.chatMessageScrollOffset = nil
    self.chatRequestMode = false
    self:setChatControlsVisible(true)
end

function target:selectChatRequestByIndex(index)
    local requests = self:getChatRequests()
    local entry = requests[index]
    if not entry then return end
    self.chatSelectedRequestUser = entry.from
    self.chatSelectedUser = nil
    self.chatExpandedMessageIndex = nil
    self.chatMessageScrollOffset = nil
    self.chatRequestMode = false
    self:setChatControlsVisible(true)
end

function target:sendChatRequest()
    local fromUser = self:getActiveChatUser()
    local toUser = ComputerModChat.trim(self.chatRequestEntry and self.chatRequestEntry:getText() or "")
    if fromUser == "" then
        self:showError(tr("Sign in first."))
        return
    end
    if not ComputerModChat.isValidUsername(toUser) then
        self:showError(tr("Enter a valid user name."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "SendRequest", {fromUser = fromUser, toUser = toUser})
        return
    end
    local success, reason = ComputerModChat.sendRequest(fromUser, toUser)
    if success then
        self.chatRequestMode = false
        if self.chatRequestEntry then self.chatRequestEntry:setText("") end
        self.fileNoticeText = tr("Request sent.")
        self.fileNoticeTimer = 120
        if ModData.transmit then
            ModData.transmit(ComputerModChat.storeName)
        end
        self:setChatControlsVisible(true)
    else
        local message
        if reason == "missing" then
            message = tr("That user does not exist.")
        elseif reason == "pending" then
            message = tr("Request already sent.")
        elseif reason == "contact" then
            message = tr("That contact is already linked.")
        elseif reason == "self" then
            message = tr("You cannot add yourself.")
        else
            message = tr("Request could not be sent.")
        end
        self:showError(message)
    end
end

function target:acceptSelectedChatRequest()
    local request = self:getSelectedChatRequest()
    local username = self:getActiveChatUser()
    if not request or username == "" then
        self:showError(tr("Select a request first."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "AcceptRequest", {username = username, fromUser = request.from})
        return
    end
    local success = ComputerModChat.acceptRequest(username, request.from)
    if success then
        if ComputerModSPActivity then
            ComputerModSPActivity.onChatRequestAccepted(username, request.from)
        end
        self.chatSelectedUser = request.from
        self.chatSelectedRequestUser = nil
        self.chatMessageScrollOffset = nil
        self.fileNoticeText = tr("Request accepted.")
        self.fileNoticeTimer = 120
        if ModData.transmit then
            ModData.transmit(ComputerModChat.storeName)
        end
        self:setChatControlsVisible(true)
    else
        self:showError(tr("Request could not be accepted."))
    end
end

function target:sendChatMessage()
    local fromUser = self:getActiveChatUser()
    local partner = self:getSelectedChatPartner()
    local body = tostring(self.chatMessageEntry and self.chatMessageEntry:getText() or "")
    if fromUser == "" or not partner then
        self:showError(tr("Select a contact first."))
        return
    end
    if ComputerModChat.trim(body) == "" then
        self:showError(tr("Write a message first."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModChat", "SendMessage", {fromUser = fromUser, toUser = partner.username, body = body})
        return
    end
    local success, reason = ComputerModChat.sendMessage(fromUser, partner.username, body)
    if success then
        if self.chatMessageEntry then self.chatMessageEntry:setText("") end
        self.chatMessageScrollOffset = nil
        self.fileNoticeText = ""
        self.fileNoticeTimer = 0
        if ModData.transmit then
            ModData.transmit(ComputerModChat.storeName)
        end
        self:setChatControlsVisible(true)
    else
        self:showError(reason == "contact" and tr("Add this user first.") or tr("Message could not be sent."))
    end
end

function target:handleChatServerCommand(command, args)
    args = args or {}
    if command == "CreateResult" then
        if args.success then
            local data = self:getComputerData()
            if data then
                data.ComputerModChatUsername = ComputerModChat.normalizeUsername(args.username or "")
                if self.computer then
                    ComputerModComputerTypes.transmitData(self.computer)
                end
            end
            self:setChatSessionUser(args.username, true)
            self.chatRequestMode = false
            self.fileNoticeText = tr("Account created.")
            self.fileNoticeTimer = 120
            self:setChatControlsVisible(true)
        else
            if args.reason == "exists" then
                self:showError(tr("That user name already exists."))
            elseif args.reason == "mail" then
                self:showError(tr("That mailbox does not exist."))
            else
                self:showError(tr("Chat account could not be created."))
            end
        end
        return
    end
    if command == "RecoveryRequestResult" then
        if args.success then
            self.fileNoticeText = tr("Password reset link sent.")
            self.fileNoticeTimer = 180
        else
            self:showError(tr("Password recovery is unavailable for this account."))
        end
        return
    end
    if command == "PasswordResetResult" then
        if args.success then
            self.accountRecoveryService = nil
            self.accountRecoveryUsername = nil
            self.accountRecoveryRequestId = nil
            self:setChatSessionUser(args.username, true)
            self.fileNoticeText = tr("Password updated.")
            self.fileNoticeTimer = 180
            self:setChatControlsVisible(true)
        else
            self:showError(args.reason == "password" and tr("Enter a user name and password.") or tr("Password reset link expired."))
        end
        return
    end
    if command == "LoginResult" then
        if args.success then
            local data = self:getComputerData()
            if data then
                data.ComputerModChatUsername = ComputerModChat.normalizeUsername(args.username or "")
            end
            self:setChatSessionUser(args.username, true)
            self.chatRequestMode = false
            self.fileNoticeText = ""
            self.fileNoticeTimer = 0
            self:setChatControlsVisible(true)
        else
            self:showError(tr("Chat login failed."))
        end
        return
    end
    if command == "RequestResult" then
        if args.success then
            self.chatRequestMode = false
            if self.chatRequestEntry then self.chatRequestEntry:setText("") end
            self.fileNoticeText = tr("Request sent.")
            self.fileNoticeTimer = 120
            self:setChatControlsVisible(true)
        elseif args.reason == "auth" then
            self:setChatSessionUser(nil, false)
            self:showError(tr("Sign in first."))
            self:setChatControlsVisible(true)
        else
            local message
            if args.reason == "missing" then
                message = tr("That user does not exist.")
            elseif args.reason == "pending" then
                message = tr("Request already sent.")
            elseif args.reason == "contact" then
                message = tr("That contact is already linked.")
            elseif args.reason == "self" then
                message = tr("You cannot add yourself.")
            else
                message = tr("Request could not be sent.")
            end
            self:showError(message)
        end
        return
    end
    if command == "AcceptResult" then
        if args.success then
            self.chatSelectedUser = ComputerModChat.normalizeUsername(args.fromUser or "")
            self.chatSelectedRequestUser = nil
            self.chatMessageScrollOffset = nil
            self.fileNoticeText = tr("Request accepted.")
            self.fileNoticeTimer = 120
        elseif args.reason == "auth" then
            self:setChatSessionUser(nil, false)
            self:showError(tr("Sign in first."))
        else
            self:showError(tr("Request could not be accepted."))
        end
        self:setChatControlsVisible(true)
        return
    end
    if command == "MessageResult" then
        if args.success then
            if self.chatMessageEntry then self.chatMessageEntry:setText("") end
            self.chatMessageScrollOffset = nil
            self.fileNoticeText = ""
            self.fileNoticeTimer = 0
        elseif args.reason == "auth" then
            self:setChatSessionUser(nil, false)
            self:showError(tr("Sign in first."))
        else
            self:showError(args.reason == "contact" and tr("Add this user first.") or tr("Message could not be sent."))
        end
        self:setChatControlsVisible(true)
        return
    end
end

function target:startChat()
    if ComputerModSandbox and not ComputerModSandbox.getBool("EnableChatApp", true) then
        self:showDesktopHome()
        return
    end
    if not self:requireInternet() then return end
    if ComputerModChatClient and ComputerModChatClient.requestSync then
        ComputerModChatClient.requestSync()
    end
    if ComputerModSPActivity then
        ComputerModSPActivity.registerChatForUI(self)
        ComputerModSPActivity.update()
    end
    self:saveCurrentNote()
    self.currentView = "CHAT"
    self.accountRecoveryService = nil
    self.accountRecoveryUsername = nil
    self.accountRecoveryRequestId = nil
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self.chatRequestMode = false
    if self.chatUserEntry then
        self.chatUserEntry:setText(tostring((self:getComputerData() and self:getComputerData().ComputerModChatUsername) or ""))
    end
    if self.chatPasswordEntry then
        self.chatPasswordEntry:setText("")
    end
    if self.chatRecoveryEmailEntry then
        self.chatRecoveryEmailEntry:setText("")
    end
    if self.chatRequestEntry then
        self.chatRequestEntry:setText("")
    end
    if self.chatMessageEntry then
        self.chatMessageEntry:setText("")
    end
    self.chatExpandedMessageIndex = nil
    self.chatMessageScrollOffset = nil
    self.chatSelectedRequestUser = nil
    if not self:getSelectedChatPartner() then
        self.chatSelectedUser = nil
    end
    self:setChatControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:selectAvatar(button)
    local data = self:getComputerData()
    if not data or not button then return end
    data.ComputerModAvatar = button.internal or 1
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:openSettingsWindow()
    self:saveCurrentNote()
    self:applyComputerTextSize()
    self.currentView = "SETTINGS"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self.fileButton:setVisible(false)
    self.notepadButton:setVisible(false)
    self.browserButton:setVisible(false)
    self.calculatorButton:setVisible(false)
    self.gamesMenuButton:setVisible(false)
    if self.settingsDesktopButton then self.settingsDesktopButton:setVisible(false) end
    self.pongButton:setVisible(false)
    self.snakeButton:setVisible(false)
    self.minesweeperButton:setVisible(false)
    self.tetrisButton:setVisible(false)
    self.spaceInvadersButton:setVisible(false)
    self.doomButton:setVisible(false)
    self.racerButton:setVisible(false)
    if self.flappyButton then self.flappyButton:setVisible(false) end
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setResetConfirmControlsVisible(false)
    self:setInstallControlsVisible(false)
    self.settingsCategory = self.settingsCategory or "profile"
    self:updateSettingsCategoryLayout()
    self:setSettingsControlsVisible(true)
    if self.usernameEntry then
        self.usernameEntry:setText(self:getComputerUsername())
        self.usernameEntry:bringToTop()
    end
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:startMail()
    if not self:requireInternet() then return end
    if ComputerModMailClient and ComputerModMailClient.requestSync then
        ComputerModMailClient.requestSync()
    end
    self:saveCurrentNote()
    self.currentView = "MAIL"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:syncComputerMailAccount()
    if ComputerModSPActivity then
        ComputerModSPActivity.registerMailForComputer(self)
        ComputerModSPActivity.update()
    end
    self.mailComposeMode = false
    self:setMailControlsVisible(true)
    if self.mailAddressEntry then
        local preferredAddress = self:getPreferredMailAccount()
        local computerAddress = tostring((self:getComputerData() and self:getComputerData().ComputerModMailAddress) or "")
        self.mailAddressEntry:setText(preferredAddress ~= "" and preferredAddress or computerAddress)
    end
    if self.mailPasswordEntry then
        self.mailPasswordEntry:setText("")
    end
    self.mailSelectedMessageId = nil
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:startMusicPlayer()
    self:saveCurrentNote()
    self.currentView = "MUSIC"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:startPaint()
    self:saveCurrentNote()
    self.activePaintKey = nil
    self.currentView = "PAINT"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    self:setChatControlsVisible(false)
    if self.notepadEntry then self.notepadEntry:setVisible(false) end
    if self.browserAddressEntry then self.browserAddressEntry:setVisible(false) end
    if self.browserGoButton then self.browserGoButton:setVisible(false) end
    if self.browserMediaButton then self.browserMediaButton:setVisible(false) end
    if self.browserDownloadButton then self.browserDownloadButton:setVisible(false) end
    self.paintCanvasW = 32
    self.paintCanvasH = 18
    self.paintCanvas = {}
    self.paintColor = self.paintColor or 2
    self.paintNoticeText = nil
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:openPaintFile(fileKey)
    local file = self:getPaintFileByKey(fileKey)
    if not file then
        self:startPaint()
        return
    end
    self:startPaint()
    self.activePaintKey = file.key
    self.paintCanvasW = file.width or 32
    self.paintCanvasH = file.height or 18
    self.paintCanvas = {}
    if type(file.cells) == "table" then
        for key, value in pairs(file.cells) do
            self.paintCanvas[key] = value
        end
    end
end

function target:savePaintDrawing()
    local data = self:getComputerData()
    if not data then return end
    local files = self:getPaintFiles()
    local name = "Drawing"
    if self.activePaintKey then
        local existing = self:getPaintFileByKey(self.activePaintKey)
        if existing and existing.name then
            name = existing.name
        end
    else
        name = "Drawing " .. tostring(#files + 1)
    end
    local saved = {
        key = self.activePaintKey or self:generatePaintFileKey(),
        name = name,
        width = self.paintCanvasW or 32,
        height = self.paintCanvasH or 18,
        cells = {}
    }
    for key, value in pairs(self.paintCanvas or {}) do
        saved.cells[key] = value
    end
    if self.activePaintKey then
        local _, index = self:getPaintFileByKey(self.activePaintKey)
        if index then
            files[index] = saved
        else
            files[#files + 1] = saved
        end
    else
        files[#files + 1] = saved
    end
    self.activePaintKey = saved.key
    data.ComputerModPaintFiles = files
    data.ComputerModFactoryReset = false
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    self.paintNoticeText = tr("Saved to desktop.")
    self.paintNoticeTimer = 120
end

function target:clearPaintDrawing()
    self.paintCanvas = {}
    self.paintNoticeText = tr("Canvas cleared.")
    self.paintNoticeTimer = 90
end

function target:deleteActivePaintDrawing()
    if self.activePaintKey and self:deletePaintFileByKey(self.activePaintKey) then
        self.activePaintKey = nil
        self.paintCanvas = {}
        self.paintNoticeText = tr("Drawing deleted.")
        self.paintNoticeTimer = 90
    else
        self:showError(tr("Save first to delete."))
    end
end

function target:getBoardPosts()
    local store = ComputerModPosts.getStore()
    return type(store.posts) == "table" and store.posts or {}
end

function target:startPostsBoard()
    if ComputerModSandbox and not ComputerModSandbox.getBool("EnableBoardApp", true) then
        self:showDesktopHome()
        return
    end
    if not self:requireInternet() then return end
    if ComputerModSPActivity then
        ComputerModSPActivity.update()
    end
    if ComputerModPostsClient and ComputerModPostsClient.requestSync then
        ComputerModPostsClient.requestSync()
    end
    self:saveCurrentNote()
    self.currentView = "BOARD"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    if self.postsNameEntry then
        self.postsNameEntry:setText(self:getComputerUsername())
    end
    if self.postsBodyEntry then
        self.postsBodyEntry:setText("")
    end
    self.boardScrollOffset = 0
    self.boardExpandedPostIndex = nil
    if self.postsSendButton then
        self.postsSendButton:setVisible(true)
    end
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:submitBoardPost()
    local name = tostring(self.postsNameEntry and self.postsNameEntry:getText() or "")
    local body = tostring(self.postsBodyEntry and self.postsBodyEntry:getText() or "")
    if ComputerModPosts.trim(body) == "" then
        self:showError(tr("Write something first."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModPosts", "AddPost", {name = name, body = body})
        return
    end
    local success = ComputerModPosts.addPost(name, body)
    if success then
        if self.postsBodyEntry then
            self.postsBodyEntry:setText("")
        end
        self.fileNoticeText = tr("Post shared.")
        self.fileNoticeTimer = 120
        if ModData.transmit then
            ModData.transmit(ComputerModPosts.storeName)
        end
    else
        self:showError(tr("Post could not be shared."))
    end
end

function target:handlePostsServerCommand(command, args)
    args = args or {}
    if command == "AddPostResult" then
        if args.success then
            if self.postsBodyEntry then
                self.postsBodyEntry:setText("")
            end
            self.boardScrollOffset = 0
            self.boardExpandedPostIndex = nil
            self.fileNoticeText = tr("Post shared.")
            self.fileNoticeTimer = 120
        else
            self:showError(tr("Post could not be shared."))
        end
    end
end

function target:getMarketData()
    local data = self:getComputerData()
    local username = self.marketAccount or (data and data.ComputerModMarketSessionUser) or nil
    local account = username and ComputerModMarket and ComputerModMarket.getAccount(username) or nil
    if account then
        if ComputerModMarket.prepareJobProgress then
            account = ComputerModMarket.prepareJobProgress(username, ComputerModMarket.getPlayerZombieKills and ComputerModMarket.getPlayerZombieKills(self.playerObj or getPlayer()) or 0) or account
        end
        return account
    end
    return {money = 0, purchases = {}, completedJobs = {}, dailyShop = {}, dailyJobs = {}}
end

function target:isMarketLoggedIn()
    local data = self:getComputerData()
    local username = self.marketAccount or (data and data.ComputerModMarketSessionUser) or nil
    return username ~= nil and username ~= ""
end

function target:getMarketUsername()
    local data = self:getComputerData()
    return self.marketAccount or (data and data.ComputerModMarketSessionUser) or nil
end

function target:getMarketShopItems()
    local account = self:getMarketData()
    local source = type(account.dailyShop) == "table" and account.dailyShop or {}
    local category = self.marketCategory or "all"
    if category == "all" then return source end
    local filtered = {}
    for i = 1, #source do
        if source[i].category == category then
            filtered[#filtered + 1] = source[i]
        end
    end
    return filtered
end

function target:getMarketJobs()
    local account = self:getMarketData()
    if type(account.dailyJobs) == "table" then return account.dailyJobs end
    return {}
end

function target:getMarketJobById(jobId)
    local jobs = self:getMarketJobs()
    for i = 1, #jobs do
        if jobs[i] and jobs[i].id == jobId then
            return jobs[i]
        end
    end
    return nil
end

function target:startMarket()
    if ComputerModSandbox and not ComputerModSandbox.getBool("EnableCommerceApp", true) then
        self:showDesktopHome()
        return
    end
    if not self:requireInternet() then return end
    if ComputerModMarketClient and ComputerModMarketClient.requestSync then
        ComputerModMarketClient.requestSync()
    end
    self:saveCurrentNote()
    self.currentView = "MARKET"
    self.accountRecoveryService = nil
    self.accountRecoveryUsername = nil
    self.accountRecoveryRequestId = nil
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    self:setChatControlsVisible(false)
    self:setPostsControlsVisible(false)
    self.marketTab = self.marketTab or "shop"
    self.marketCategory = self.marketCategory or "all"
    local data = self:getComputerData()
    if data and data.ComputerModMarketSessionUser then
        self.marketAccount = data.ComputerModMarketSessionUser
    end
    if self.marketRecoveryEmailEntry and not self:isMarketLoggedIn() then
        local activeMail = self:getActiveMailAddress()
        if activeMail ~= "" then self.marketRecoveryEmailEntry:setText(activeMail) end
    end
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:startMarketPaperworkJob(job)
    if not job then return end
    self.currentView = "MARKET_JOB"
    self.marketPaperworkJob = job
    self.marketPaperworkStep = 1
    self.marketPaperworkSequence = {}
    self.marketPaperworkErrorTimer = 0
    local seed = ComputerModMarket and ComputerModMarket.hash and ComputerModMarket.hash(tostring(job.id or "") .. ":" .. tostring(self:getMarketUsername() or "")) or ZombRand(9999)
    local modes = {"fields", "codes", "checksum"}
    self.marketPaperworkMode = modes[(seed % #modes) + 1]
    self.marketPaperworkLabels = {}
    self.marketPaperworkPrompt = ""
    local length = self.marketPaperworkMode == "fields" and 6 or 5
    if self.marketPaperworkMode == "fields" then
        self.marketPaperworkLabels = {"Invoice", "Stock", "Date", "Code"}
        self.marketPaperworkPrompt = "File the highlighted fields in order."
        for i = 1, length do
            self.marketPaperworkSequence[i] = (seed % 4) + 1
            seed = math.floor(seed / 3) + i * 17
        end
    elseif self.marketPaperworkMode == "codes" then
        self.marketPaperworkLabels = {}
        for i = 1, 4 do
            local code = 100 + ((seed + i * 37) % 899)
            self.marketPaperworkLabels[i] = tostring(code)
        end
        self.marketPaperworkPrompt = "Click each shipment code from the printout."
        for i = 1, length do
            self.marketPaperworkSequence[i] = ((seed + i * 11) % 4) + 1
            seed = math.floor(seed / 5) + i * 23
        end
    else
        local values = {}
        local targetIndex = (seed % 4) + 1
        local targetValue = 0
        for i = 1, 4 do
            values[i] = 11 + ((seed + i * 19) % 39)
            if i == targetIndex then targetValue = values[i] end
        end
        for i = 1, 4 do
            self.marketPaperworkLabels[i] = tostring(values[i])
        end
        self.marketPaperworkPrompt = "Select numbers matching the requested checksum."
        for i = 1, length do
            self.marketPaperworkSequence[i] = ((targetIndex + i - 2) % 4) + 1
        end
    end
    self:setMarketControlsVisible(false)
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:finishMarketPaperworkJob()
    local job = self.marketPaperworkJob
    if not job then
        self.currentView = "MARKET"
        return
    end
    local username = self:getMarketUsername()
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "CompleteJob", {username = username, jobId = job.id, minigamePassed = true})
    else
        local success, result = ComputerModMarket.completeJob(username, job.id, self.playerObj or getPlayer(), nil, true)
        if success then
            self.fileNoticeText = tr("Job paid $") .. tostring(result.reward or 0) .. "."
            self.fileNoticeTimer = 120
        else
            self:showError(result == "done" and tr("Job already completed.") or tr("Job unavailable."))
        end
        if ModData and ModData.transmit then
            ModData.transmit(ComputerModMarket.storeName)
        end
    end
    self.marketPaperworkJob = nil
    self.marketPaperworkSequence = nil
    self.marketPaperworkStep = 1
    self.currentView = "MARKET"
    self.marketTab = "jobs"
    self:setMarketControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:handleMarketPaperworkChoice(choice)
    local sequence = self.marketPaperworkSequence or {}
    local step = tonumber(self.marketPaperworkStep or 1) or 1
    if sequence[step] == choice then
        self.marketPaperworkStep = step + 1
        self.marketPaperworkErrorTimer = 0
        if self.marketPaperworkStep > #sequence then
            self:finishMarketPaperworkJob()
        end
    else
        self.marketPaperworkStep = 1
        self.marketPaperworkErrorTimer = 0
        self:showError(tr("Wrong field. Start again."))
    end
end

function target:handleMarketPrimaryAction()
    local username = ComputerModMarket.trim(self.marketUserEntry and self.marketUserEntry:getText() or "")
    local password = ComputerModMarket.trim(self.marketPasswordEntry and self.marketPasswordEntry:getText() or "")
    local recoveryEmail = ComputerModMail.normalizeAddress(self.marketRecoveryEmailEntry and self.marketRecoveryEmailEntry:getText() or "")
    if recoveryEmail == "" then recoveryEmail = self:getActiveMailAddress() end
    if not ComputerModMarket.isValidUsername(username) then
        self:showError(tr("Enter a username or email with at least 3 characters."))
        return
    end
    if password == "" then
        self:showError(tr("Enter a password."))
        return
    end
    if not ComputerModMail.isValidAddress(recoveryEmail) then
        self:showError(tr("Enter a full address like user@server."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "CreateAccount", {username = username, password = password, recoveryEmail = recoveryEmail})
        return
    end
    local success, result = ComputerModMarket.createAccount(username, password, recoveryEmail)
    if success then
        local normalized = ComputerModMarket.normalizeUsername(username)
        self.marketAccount = normalized
        local data = self:getComputerData()
        if data then data.ComputerModMarketSessionUser = normalized end
        self.fileNoticeText = tr("Market account created.")
        self.fileNoticeTimer = 120
    else
        if result == "exists" then
            self:showError(tr("Account already exists."))
        elseif result == "mail" then
            self:showError(tr("That mailbox does not exist."))
        else
            self:showError(tr("Invalid market account."))
        end
    end
    self:updateStartMenuButtons()
end

function target:requestMarketPasswordReset()
    local username = ComputerModMarket.normalizeUsername(self.marketUserEntry and self.marketUserEntry:getText() or "")
    if not ComputerModMarket.isValidUsername(username) then
        self:showError(tr("Invalid market account."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "RequestPasswordReset", {username = username})
        return
    end
    local account = ComputerModMarket.getAccount(username)
    if not account or not account.recoveryEmail or not ComputerModMail.getAccount(account.recoveryEmail) or not sendLocalRecoveryMessage("market", username, account.recoveryEmail) then
        self:showError(tr("Password recovery is unavailable for this account."))
        return
    end
    self.fileNoticeText = tr("Password reset link sent.")
    self.fileNoticeTimer = 180
end

function target:submitMarketPasswordReset()
    if self.accountRecoveryService ~= "market" then return end
    local password = ComputerModMarket.trim(self.marketPasswordEntry and self.marketPasswordEntry:getText() or "")
    if password == "" then
        self:showError(tr("Invalid market account."))
        return
    end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "ResetPassword", {
            requestId = self.accountRecoveryRequestId,
            password = password
        })
        return
    end
    local success, username = ComputerModAccountRecovery.consume(self.playerObj or getPlayer(), self.accountRecoveryRequestId, "market")
    local account = success and ComputerModMarket.getAccount(username) or nil
    if not account then
        self:showError(tr("Password reset link expired."))
        return
    end
    account.password = password
    self.accountRecoveryService = nil
    self.accountRecoveryUsername = nil
    self.accountRecoveryRequestId = nil
    self.marketAccount = username
    local data = self:getComputerData()
    if data then data.ComputerModMarketSessionUser = username end
    if ModData.transmit then
        ModData.transmit(ComputerModMarket.storeName)
        ModData.transmit(ComputerModAccountRecovery.storeName)
    end
    self.fileNoticeText = tr("Password updated.")
    self.fileNoticeTimer = 180
    self:setMarketControlsVisible(true)
    self:updateStartMenuButtons()
end

function target:handleMarketSecondaryAction()
    local username = tostring(self.marketUserEntry and self.marketUserEntry:getText() or "")
    local password = tostring(self.marketPasswordEntry and self.marketPasswordEntry:getText() or "")
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "Login", {username = username, password = password})
        return
    end
    local success, result = ComputerModMarket.login(username, password)
    if success then
        local normalized = ComputerModMarket.normalizeUsername(username)
        self.marketAccount = normalized
        local data = self:getComputerData()
        if data then data.ComputerModMarketSessionUser = normalized end
        self.fileNoticeText = tr("Logged in.")
        self.fileNoticeTimer = 120
    else
        self:showError(result == "password" and tr("Wrong password.") or tr("Account not found."))
    end
    self:updateStartMenuButtons()
end

function target:handleMarketServerCommand(command, args)
    args = args or {}
    local message = nil
    local isError = false
    if command == "CreateResult" or command == "LoginResult" then
        if args.success then
            self.marketAccount = ComputerModMarket.normalizeUsername(args.username)
            local data = self:getComputerData()
            if data then data.ComputerModMarketSessionUser = self.marketAccount end
            message = command == "CreateResult" and tr("Market account created.") or tr("Logged in.")
        else
            isError = true
            local reason = tostring(args.reason or "")
            if reason == "exists" then
                message = tr("Account already exists.")
            elseif reason == "password" then
                message = tr("Wrong password.")
            elseif reason == "missing" then
                message = tr("Account not found.")
            elseif reason == "mail" then
                message = tr("That mailbox does not exist.")
            elseif reason == "invalid" then
                message = tr("Enter a username or email with at least 3 characters.")
            else
                message = tr("Invalid market account.")
            end
        end
    elseif command == "RecoveryRequestResult" then
        if args.success then
            message = tr("Password reset link sent.")
        else
            message = tr("Password recovery is unavailable for this account.")
            isError = true
        end
    elseif command == "PasswordResetResult" then
        if args.success then
            self.accountRecoveryService = nil
            self.accountRecoveryUsername = nil
            self.accountRecoveryRequestId = nil
            self.marketAccount = ComputerModMarket.normalizeUsername(args.username)
            local data = self:getComputerData()
            if data then data.ComputerModMarketSessionUser = self.marketAccount end
            message = tr("Password updated.")
            self:setMarketControlsVisible(true)
        else
            message = args.reason == "password" and tr("Invalid market account.") or tr("Password reset link expired.")
            isError = true
        end
    elseif command == "BuyResult" then
        if args.success then
            message = tr("Purchase complete.")
        elseif tostring(args.reason or "") == "auth" then
            self.marketAccount = nil
            local data = self:getComputerData()
            if data then data.ComputerModMarketSessionUser = nil end
            message = tr("Sign in first.")
            isError = true
        elseif tostring(args.reason or "") == "money" then
            message = tr("Not enough money.")
            isError = true
        elseif tostring(args.reason or "") == "stock" then
            message = tr("Out of stock.")
            isError = true
        else
            message = tr("Purchase failed.")
            isError = true
        end
    elseif command == "JobResult" then
        if args.success then
            message = tr("Job paid.")
        elseif tostring(args.reason or "") == "auth" then
            self.marketAccount = nil
            local data = self:getComputerData()
            if data then data.ComputerModMarketSessionUser = nil end
            message = tr("Sign in first.")
            isError = true
        elseif tostring(args.reason or "") == "progress" then
            message = tr("Objective not finished.")
            isError = true
        elseif tostring(args.reason or "") == "items" then
            message = tr("Required items missing.")
            isError = true
        elseif tostring(args.reason or "") == "done" then
            message = tr("Job already completed.")
            isError = true
        else
            message = tr("Job unavailable.")
            isError = true
        end
    elseif command == "DebugMoneyResult" then
        if args.success then
            message = tr("Debug money added.")
        elseif tostring(args.reason or "") == "auth" then
            self.marketAccount = nil
            local data = self:getComputerData()
            if data then data.ComputerModMarketSessionUser = nil end
            message = tr("Sign in first.")
        else
            message = tr("Admin required.")
        end
        isError = not args.success
    elseif command == "ResetShopResult" then
        message = args.success and tr("Shop stock refreshed.") or tr("Admin required.")
        isError = not args.success
    elseif command == "ResetJobsResult" then
        message = args.success and tr("Jobs refreshed.") or tr("Admin required.")
        isError = not args.success
    end
    if message then
        if isError then
            self:showError(message)
        else
            self.fileNoticeText = message
            self.fileNoticeTimer = 120
        end
    end
    self:updateStartMenuButtons()
end

function target:logOutMarket()
    if isClient and isClient() and sendClientCommand then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "Logout", {})
    end
    self.marketAccount = nil
    local data = self:getComputerData()
    if data then data.ComputerModMarketSessionUser = nil end
    self.fileNoticeText = tr("Logged out.")
    self.fileNoticeTimer = 120
    self:updateStartMenuButtons()
end

function target:showMarketShop()
    self.marketTab = "shop"
    self.marketShopScrollOffset = 0
    self:updateStartMenuButtons()
end

function target:showMarketJobs()
    self.marketTab = "jobs"
    self.marketJobsScrollOffset = 0
    self:updateStartMenuButtons()
end

function target:selectMarketCategory(category)
    self.marketCategory = category or "all"
    self.marketTab = "shop"
    self.marketShopScrollOffset = 0
    self:updateStartMenuButtons()
end

function target:grantMarketDebugMoney()
    if not self:isMarketLoggedIn() or not isDebugModeEnabled(self.playerObj) then return end
    local username = self:getMarketUsername()
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "DebugMoney", {username = username})
        return
    end
    if isDebugModeEnabled(self.playerObj) and ComputerModMarket.addDebugMoney(username, 1000) then
        self.fileNoticeText = tr("Debug money added.")
        self.fileNoticeTimer = 120
    else
        self:showError(tr("Admin required."))
    end
end

function target:resetMarketShop()
    if not self:isMarketLoggedIn() or not isDebugModeEnabled(self.playerObj) then return end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "ResetShop", {username = self:getMarketUsername()})
        return
    end
    ComputerModMarket.resetDaily("shop")
    self.fileNoticeText = tr("Shop stock refreshed.")
    self.fileNoticeTimer = 120
    if ModData and ModData.transmit then
        ModData.transmit(ComputerModMarket.storeName)
    end
end

function target:resetMarketJobs()
    if not self:isMarketLoggedIn() or not isDebugModeEnabled(self.playerObj) then return end
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "ResetJobs", {username = self:getMarketUsername()})
        return
    end
    ComputerModMarket.resetDaily("jobs")
    self.fileNoticeText = tr("Jobs refreshed.")
    self.fileNoticeTimer = 120
    if ModData and ModData.transmit then
        ModData.transmit(ComputerModMarket.storeName)
    end
end

function target:addMarketItemToInventory(fullType)
    local playerObj = self.playerObj or (getPlayer and getPlayer()) or nil
    if not playerObj or not playerObj.getInventory or not fullType then return false end
    local inventory = playerObj:getInventory()
    if not inventory or not inventory.AddItem then return false end
    local item = nil
    if instanceItem then
        local okInstance, created = pcall(function() return instanceItem(fullType) end)
        if okInstance then item = created end
    end
    if not item and InventoryItemFactory and InventoryItemFactory.CreateItem then
        local okCreate, created = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
        if okCreate then item = created end
    end
    -- B42's string overload can throw inside MultiLuaJavaInvoker when the
    -- script item cannot be resolved. Only add a successfully-created object.
    if not item then return false end
    local ok = pcall(function() inventory:AddItem(item) end)
    return ok == true and item ~= nil
end

function target:buyMarketItem(itemId)
    if not self:isMarketLoggedIn() then return end
    local username = self:getMarketUsername()
    if isClient and isClient() then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "BuyItem", {username = username, itemId = itemId})
        return
    end
    local valid, account, item = ComputerModMarket.validatePurchase(username, itemId)
    local success = false
    local result = account
    if valid and item then
        local purchased
        success, purchased = ComputerModMarket.applyPurchase(username, itemId)
        if success and purchased then
            if self:addMarketItemToInventory(purchased.fullType or item.fullType) then
                result = purchased
            else
                account.money = (tonumber(account.money or 0) or 0) + (tonumber(purchased.price or item.price or 0) or 0)
                purchased.stock = (tonumber(purchased.stock or 0) or 0) + 1
                success = false
                result = "item"
            end
        else
            result = purchased
        end
    end
    if success then
        self.fileNoticeText = tr("Purchased ") .. tostring(result.label or "item") .. "."
        self.fileNoticeTimer = 120
    else
        local message
        if result == "money" then
            message = tr("Not enough money.")
        elseif result == "stock" then
            message = tr("Out of stock.")
        else
            message = tr("Purchase failed.")
        end
        self:showError(message)
    end
    if ModData and ModData.transmit then
        ModData.transmit(ComputerModMarket.storeName)
    end
end

function target:completeMarketJob(jobId)
    if not self:isMarketLoggedIn() then return end
    local job = self:getMarketJobById(jobId)
    if job and job.type == "paperwork" then
        local account = self:getMarketData()
        if account and account.completedJobs and account.completedJobs[job.id] then
            self:showError(tr("Job already completed."))
            return
        end
        self:startMarketPaperworkJob(job)
        return
    end
    local username = self:getMarketUsername()
    if isClient and isClient() then
        local account = self:getMarketData()
        local progress = account and account.jobProgress and account.jobProgress[jobId] or nil
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModMarket", "CompleteJob", {username = username, jobId = jobId, startKills = progress and progress.startKills or nil})
        return
    end
    local success, result = ComputerModMarket.completeJob(username, jobId, self.playerObj or getPlayer(), nil, false)
    if success then
        self.fileNoticeText = tr("Job paid $") .. tostring(result.reward or 0) .. "."
        self.fileNoticeTimer = 120
    else
        local message
        if result == "done" then
            message = tr("Job already completed.")
        elseif result == "progress" then
            message = tr("Objective not finished.")
        elseif result == "items" then
            message = tr("Required items missing.")
        else
            message = tr("Job unavailable.")
        end
        self:showError(message)
    end
    if ModData and ModData.transmit then
        ModData.transmit(ComputerModMarket.storeName)
    end
end

function target:openTrashFolder()
    self.currentView = "TRASH"
    self.currentFolderName = nil
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:openFolderView(folderName)
    if not folderName or folderName == "" then return end
    self.currentView = "FOLDER"
    self.currentFolderName = folderName
    self.folderScrollOffset = 0
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    self:setFolderEditControlsVisible(false)
    self:moveCloseToWindow()
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:startFolderEdit(mode, existingName)
    self.currentView = "FOLDER_EDIT"
    self.folderEditMode = mode or "create"
    self.folderEditTarget = existingName
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setDesktopShortcutsVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setInstallControlsVisible(false)
    self:setSettingsControlsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setMailControlsVisible(false)
    self:setFolderEditControlsVisible(true)
    if self.folderNameEntry then
        self.folderNameEntry:setText(existingName or "")
        self.folderNameEntry:bringToTop()
    end
    if self.folderSaveButton then
        self.folderSaveButton:setTitle((mode == "rename" or mode == "rename_cd") and tr("Rename") or tr("Create"))
    end
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:confirmFolderEdit()
    local data = self:getComputerData()
    if not data or not self.folderNameEntry or not self.folderNameEntry.getText then return end
    local name = tostring(self.folderNameEntry:getText() or "")
    name = string.gsub(name, "^%s+", "")
    name = string.gsub(name, "%s+$", "")
    if name == "" then
        self:showError(tr("Enter a folder name."))
        return
    end
    if self.folderEditMode == "rename_cd" then
        data.ComputerModMountedCDLabel = name
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        self:startFiles()
        return
    elseif self.folderEditMode == "create_note" then
        local notes = self:getDesktopNotes()
        for i = 1, #notes do
            if notes[i] and string.lower(notes[i].name or "") == string.lower(name) then
                self:showError(tr("That note already exists."))
                return
            end
        end
        local note = {key = self:generateDesktopNoteKey(), name = name, text = ""}
        notes[#notes + 1] = note
        data.ComputerModDesktopNotes = notes
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        self:openDesktopNote(note.key)
        return
    else
        local folders = self:getComputerFolders()
        for i = 1, #folders do
            if string.lower(folders[i]) == string.lower(name) and folders[i] ~= self.folderEditTarget then
                self:showError(tr("That folder already exists."))
                return
            end
        end
        data.ComputerModFolderContents = data.ComputerModFolderContents or {}
        data.ComputerModUserFolders = data.ComputerModUserFolders or {}
        if self.folderEditMode == "rename" and self.folderEditTarget and self.folderEditTarget ~= "" then
            for i = 1, #folders do
                if folders[i] == self.folderEditTarget then
                    folders[i] = name
                    data.ComputerModFolderContents[name] = data.ComputerModFolderContents[self.folderEditTarget] or {}
                    data.ComputerModFolderContents[self.folderEditTarget] = nil
                    data.ComputerModUserFolders[name] = data.ComputerModUserFolders[self.folderEditTarget] == true
                    data.ComputerModUserFolders[self.folderEditTarget] = nil
                    break
                end
            end
        else
            folders[#folders + 1] = name
            data.ComputerModFolderContents[name] = {}
            data.ComputerModUserFolders[name] = true
        end
        data.ComputerModFolders = folders
        data.ComputerModFactoryReset = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        if self.folderEditReturnView == "DESKTOP" then
            self:showDesktopHome()
        else
            self:startFiles()
        end
    end
end

function target:cancelFolderEdit()
    if self.folderEditReturnView == "DESKTOP" then
        self:showDesktopHome()
    else
        self:startFiles()
    end
end

function target:logOffComputer()
    self:saveCurrentNote()
    self.passwordUnlocked = false
    local data = self:getComputerData()
    if data then
        data.ComputerModSessionUnlocked = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    self:openLockScreen()
end

function target:openOSFirstRunSetup()
    self.currentView = "OS_SETUP"
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:setInstallControlsVisible(true)
    if self.installNextButton then self.installNextButton:setTitle(tr("Finish")) end
    if self.installCancelButton then self.installCancelButton:setTitle(tr("Skip")) end
    self:setPasswordControlsVisible(false)
    self:setSettingsControlsVisible(true)
    if self.usernameEntry then
        self.usernameEntry:setText(self:getComputerUsername())
        self.usernameEntry:bringToTop()
    end
    if self.passwordEntry then
        self.passwordEntry:setText("")
        self.passwordEntry:setVisible(true)
        self.passwordEntry:bringToTop()
    end
    if self.passwordActionButton then self.passwordActionButton:setVisible(false) end
    if self.passwordClearButton then self.passwordClearButton:setVisible(false) end
    if self.passwordSettingsButton then self.passwordSettingsButton:setVisible(false) end
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:finishOSFirstRunSetup()
    local data = self:getComputerData()
    if data then
        if self.usernameEntry and self.usernameEntry.getText then
            local username = tostring(self.usernameEntry:getText() or "")
            username = string.gsub(username, "^%s+", "")
            username = string.gsub(username, "%s+$", "")
            data.ComputerModUsername = username ~= "" and username or "User"
        end
        if self.passwordEntry and self.passwordEntry.getText then
            local password = tostring(self.passwordEntry:getText() or "")
            password = string.gsub(password, "^%s+", "")
            password = string.gsub(password, "%s+$", "")
            data.ComputerModPasswordEnabled = password ~= ""
            data.ComputerModPassword = password ~= "" and password or nil
        end
        data.ComputerModSessionUnlocked = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    self:setSettingsControlsVisible(false)
    if self.passwordEntry then self.passwordEntry:setVisible(false) end
    self.installGameId = nil
    self:beginBootSequence()
end

function target:openBiosMenu()
    if self:isNetworkTerminal() then
        self:openNetworkTerminal()
        return
    end
    self.currentView = "BIOS"
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
    self:setInstallControlsVisible(false)
    self.biosBootDiskButton:setWidth(uiValue(self, 120))
    self.biosBootDiskButton:setX(self.screenX + self.screenWidth - uiValue(self, 138))
    self.biosBootDiskButton:setY(self.screenY + uiValue(self, 70))
    self.biosBootCDButton:setWidth(uiValue(self, 120))
    self.biosBootCDButton:setX(self.screenX + self.screenWidth - uiValue(self, 138))
    self.biosBootCDButton:setY(self.screenY + uiValue(self, 100))
    self.biosWipeDiskButton:setWidth(uiValue(self, 120))
    self.biosWipeDiskButton:setX(self.screenX + self.screenWidth - uiValue(self, 138))
    self.biosWipeDiskButton:setY(self.screenY + uiValue(self, 130))
    self.biosExitButton:setWidth(uiValue(self, 120))
    self.biosExitButton:setX(self.screenX + self.screenWidth - uiValue(self, 138))
    self.biosExitButton:setY(self.screenY + uiValue(self, 160))
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:biosBootHardDisk()
    if self:isNetworkTerminal() then
        self:openNetworkTerminal()
        return
    end
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    if self:isOSInstalled() then
        self:beginBootSequence()
    else
        self:showBootError()
        self:updateStartMenuButtons()
    end
end

function target:biosBootCD()
    if self:isNetworkTerminal() then
        self:openNetworkTerminal()
        return
    end
    local discGame = self:getMountedDiscGame()
    if discGame == "os" then
        self:openInstallWizard("os")
        return
    end
    self:showError(tr("No bootable CD found."))
end

function target:biosWipeDisk()
    if self:isNetworkTerminal() then
        self:showError(tr("Network Recovery OS cannot be wiped."))
        self:openNetworkTerminal()
        return
    end
    self.resetReturnView = "BIOS"
    self.currentView = "RESET_CONFIRM"
    if self.resetConfirmButton then self.resetConfirmButton:setTitle(tr("Confirm Reset")) end
    if self.resetCancelButton then self.resetCancelButton:setTitle(tr("Cancel")) end
    self:setPasswordControlsVisible(false)
    self:setResetConfirmControlsVisible(true)
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:exitBiosMenu()
    if self:isNetworkTerminal() then
        self:openNetworkTerminal()
        return
    end
    if self:isOSInstalled() then
        self:beginBootSequence()
    else
        self:showBootError()
        self:updateStartMenuButtons()
    end
end

function target:debugInstallAllGames()
    if not isDebugModeEnabled(self.playerObj) then return end
    local data = self:getComputerData()
    if not data then return end
    local installed = {}
    for i = 1, #gameInstallOrder do
        installed[#installed + 1] = gameInstallOrder[i]
    end
    data.ComputerModInstalledGames = installed
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    self:layoutVisibleGameButtons()
    self:updateStartMenuButtons()
end

function target:setPasswordControlsVisible(visible)
    local function u(value) return uiValue(self, value) end
    local entryX = self.clientX + u(112)
    local actionX = self.clientX + self.clientW - u(94)
    if self.passwordEntry then
        self.passwordEntry:setX(entryX)
        self.passwordEntry:setY(self.clientY + u(92))
        self.passwordEntry:setWidth(math.max(u(128), self.clientW - u(234)))
    end
    if self.passwordActionButton then
        self.passwordActionButton:setX(actionX)
        self.passwordActionButton:setY(self.clientY + u(92))
        self.passwordActionButton:setWidth(u(70))
    end
    if self.passwordHackButton then
        self.passwordHackButton:setX(actionX)
        self.passwordHackButton:setY(self.clientY + u(122))
        self.passwordHackButton:setWidth(u(70))
    end
    if self.passwordResetButton then
        self.passwordResetButton:setX(self.clientX + u(68))
        self.passwordResetButton:setY(self.clientY + u(126))
        self.passwordResetButton:setWidth(u(118))
    end
    if self.passwordClearButton then
        self.passwordClearButton:setX(self.clientX + self.clientW - u(124))
        self.passwordClearButton:setY(self.clientY + u(126))
        self.passwordClearButton:setWidth(u(118))
    end
    if self.passwordEntry then self.passwordEntry:setVisible(visible) end
    if self.passwordActionButton then self.passwordActionButton:setVisible(visible) end
    if self.passwordHackButton then self.passwordHackButton:setVisible(visible and self:canShowHackButton()) end
    if self.passwordResetButton then self.passwordResetButton:setVisible(false) end
    if self.passwordClearButton then self.passwordClearButton:setVisible(visible) end
end

function target:setSettingsControlsVisible(visible)
    local profileVisible = visible and (self.currentView == "OS_SETUP" or self.settingsCategory == "profile")
    local systemVisible = visible and (self.currentView == "SETTINGS" and self.settingsCategory == "system")
    local displayVisible = visible and self.currentView == "SETTINGS" and self.settingsCategory == "display"
    local hardwareVisible = visible and self.currentView == "SETTINGS" and self.settingsCategory == "hardware"
    self:updateSettingsCategoryLayout()
    if self.usernameEntry then self.usernameEntry:setVisible(profileVisible) end
    if self.saveUserButton then self.saveUserButton:setVisible(profileVisible and self.currentView == "SETTINGS") end
    if self.dateFormatButton then self.dateFormatButton:setVisible(systemVisible) end
    if self.debugModeButton then
        self.debugModeButton:setVisible(systemVisible)
    end
    if self.settingsProfileButton then self.settingsProfileButton:setVisible(visible and self.currentView == "SETTINGS") end
    if self.settingsSecurityButton then self.settingsSecurityButton:setVisible(visible and self.currentView == "SETTINGS") end
    if self.settingsSystemButton then self.settingsSystemButton:setVisible(visible and self.currentView == "SETTINGS") end
    if self.settingsDisplayButton then self.settingsDisplayButton:setVisible(visible and self.currentView == "SETTINGS") end
    if self.settingsControlsButton then self.settingsControlsButton:setVisible(visible and self.currentView == "SETTINGS") end
    if self.settingsHardwareButton then self.settingsHardwareButton:setVisible(visible and self.currentView == "SETTINGS") end
    if self.componentDebugButtons then
        local showDebugHardware = hardwareVisible and isDebugModeEnabled(self.playerObj)
        local data = self:getComputerData()
        for i = 1, #self.componentDebugButtons do
            local button = self.componentDebugButtons[i]
            local part = button.internal and ComputerModComponents.getPart(button.internal.partId) or nil
            button:setVisible(showDebugHardware and ComputerModComponents.isPartCompatible(part, data))
        end
    end
    local controlsVisible = visible and self.currentView == "SETTINGS" and self.settingsCategory == "controls"
    if self.gameControlProfileButton then self.gameControlProfileButton:setVisible(controlsVisible) end
    if self.gameMovementLockButton then self.gameMovementLockButton:setVisible(controlsVisible) end
    if self.avatarButtons then
        for i = 1, #self.avatarButtons do
            self.avatarButtons[i]:setVisible(profileVisible)
        end
    end
    if self.backgroundButtons then
        for i = 1, #self.backgroundButtons do
            self.backgroundButtons[i]:setVisible(displayVisible)
        end
    end
    if self.textSizeButtons then
        for i = 1, #self.textSizeButtons do
            self.textSizeButtons[i]:setVisible(displayVisible)
        end
    end
    if self.uiScaleButtons then
        for i = 1, #self.uiScaleButtons do
            self.uiScaleButtons[i]:setVisible(displayVisible)
        end
    end
    self:updateDebugModeButton()
    self:updateTextSizeButtons()
    self:updateUIScaleButtons()
    self:updateGameMovementLockButton()
end

function target:setMailControlsVisible(visible)
    local needsLogin = visible and not self:isMailLoggedIn()
    local composeVisible = visible and self:isMailLoggedIn() and self.mailComposeMode == true
    local inboxVisible = visible and self:isMailLoggedIn() and not composeVisible
    local function u(value) return uiValue(self, value) end
    local fieldX = self.clientX + u(122)
    local actionX = self.clientX + self.clientW - u(84)
    if self.mailAddressEntry then
        self.mailAddressEntry:setX(fieldX)
        self.mailAddressEntry:setY(self.clientY + u(52))
        self.mailAddressEntry:setWidth(math.max(u(176), self.clientW - u(218)))
    end
    if self.mailPasswordEntry then
        self.mailPasswordEntry:setX(fieldX)
        self.mailPasswordEntry:setY(self.clientY + u(86))
        self.mailPasswordEntry:setWidth(math.max(u(176), self.clientW - u(218)))
    end
    if self.mailPrimaryButton then
        self.mailPrimaryButton:setX(actionX)
        self.mailPrimaryButton:setY(self.clientY + u(52))
        self.mailPrimaryButton:setWidth(u(72))
    end
    if self.mailSecondaryButton then
        self.mailSecondaryButton:setX(actionX)
        self.mailSecondaryButton:setY(self.clientY + u(86))
        self.mailSecondaryButton:setWidth(u(72))
    end
    if self.mailLogoutButton then
        self.mailLogoutButton:setX(self.clientX + self.clientW - u(86))
        self.mailLogoutButton:setY(self.clientY + u(12))
        self.mailLogoutButton:setWidth(u(78))
    end
    if self.mailComposeButton then
        self.mailComposeButton:setX(self.clientX + u(10))
        self.mailComposeButton:setY(self.clientY + u(12))
        self.mailComposeButton:setWidth(u(64))
    end
    if self.mailReplyButton then
        self.mailReplyButton:setX(self.clientX + u(80))
        self.mailReplyButton:setY(self.clientY + u(12))
        self.mailReplyButton:setWidth(u(64))
    end
    if self.mailDeleteButton then
        self.mailDeleteButton:setX(self.clientX + u(150))
        self.mailDeleteButton:setY(self.clientY + u(12))
        self.mailDeleteButton:setWidth(u(64))
    end
    if self.mailRecoveryLinkButton then
        self.mailRecoveryLinkButton:setX(self.clientX + self.clientW - u(130))
        self.mailRecoveryLinkButton:setY(self.clientY + u(34))
        self.mailRecoveryLinkButton:setWidth(u(120))
    end
    if self.mailCancelButton then
        self.mailCancelButton:setX(self.clientX + self.clientW - u(164))
        self.mailCancelButton:setY(self.clientY + u(12))
        self.mailCancelButton:setWidth(u(70))
    end
    if self.mailSendButton then
        self.mailSendButton:setX(self.clientX + self.clientW - u(86))
        self.mailSendButton:setY(self.clientY + u(12))
        self.mailSendButton:setWidth(u(78))
    end
    if self.mailToEntry then
        self.mailToEntry:setX(self.clientX + u(84))
        self.mailToEntry:setY(self.clientY + u(40))
        self.mailToEntry:setWidth(self.clientW - u(96))
    end
    if self.mailSubjectEntry then
        self.mailSubjectEntry:setX(self.clientX + u(84))
        self.mailSubjectEntry:setY(self.clientY + u(68))
        self.mailSubjectEntry:setWidth(self.clientW - u(96))
    end
    if self.mailBodyEntry then
        self.mailBodyEntry:setX(self.clientX + u(10))
        self.mailBodyEntry:setY(self.clientY + u(98))
        self.mailBodyEntry:setWidth(self.clientW - u(20))
        self.mailBodyEntry:setHeight(self.clientH - u(108))
    end
    if self.mailAddressEntry then self.mailAddressEntry:setVisible(needsLogin) end
    if self.mailPasswordEntry then self.mailPasswordEntry:setVisible(needsLogin) end
    if self.mailPrimaryButton then self.mailPrimaryButton:setVisible(needsLogin) end
    if self.mailSecondaryButton then self.mailSecondaryButton:setVisible(needsLogin) end
    if self.mailLogoutButton then self.mailLogoutButton:setVisible(inboxVisible) end
    if self.mailComposeButton then self.mailComposeButton:setVisible(inboxVisible) end
    if self.mailReplyButton then self.mailReplyButton:setVisible(inboxVisible and self:getSelectedMailMessage() ~= nil) end
    if self.mailDeleteButton then self.mailDeleteButton:setVisible(inboxVisible and self:getSelectedMailMessage() ~= nil) end
    local selectedMail = inboxVisible and self:getSelectedMailMessage() or nil
    if self.mailRecoveryLinkButton then self.mailRecoveryLinkButton:setVisible(selectedMail ~= nil and selectedMail.recoveryRequestId ~= nil) end
    if self.mailCancelButton then self.mailCancelButton:setVisible(composeVisible) end
    if self.mailSendButton then self.mailSendButton:setVisible(composeVisible) end
    if self.mailToEntry then self.mailToEntry:setVisible(composeVisible) end
    if self.mailSubjectEntry then self.mailSubjectEntry:setVisible(composeVisible) end
    if self.mailBodyEntry then self.mailBodyEntry:setVisible(composeVisible) end
end

function target:setChatControlsVisible(visible)
    local recoveryMode = visible and self.accountRecoveryService == "chat"
    local needsLogin = visible and not self:isChatLoggedIn() and not recoveryMode
    local requestMode = visible and self:isChatLoggedIn() and self.chatRequestMode == true and not recoveryMode
    local chatVisible = visible and self:isChatLoggedIn() and not requestMode and not recoveryMode
    local function u(value) return uiValue(self, value) end
    local fieldX = self.clientX + u(122)
    local actionX = self.clientX + self.clientW - u(84)
    if self.chatUserEntry then
        self.chatUserEntry:setX(fieldX)
        self.chatUserEntry:setY(self.clientY + u(52))
        self.chatUserEntry:setWidth(math.max(u(176), self.clientW - u(218)))
    end
    if self.chatPasswordEntry then
        self.chatPasswordEntry:setX(fieldX)
        self.chatPasswordEntry:setY(self.clientY + u(86))
        self.chatPasswordEntry:setWidth(math.max(u(176), self.clientW - u(218)))
    end
    if self.chatRecoveryEmailEntry then
        self.chatRecoveryEmailEntry:setX(fieldX)
        self.chatRecoveryEmailEntry:setY(self.clientY + u(120))
        self.chatRecoveryEmailEntry:setWidth(math.max(u(176), self.clientW - u(218)))
    end
    if self.chatPrimaryButton then
        self.chatPrimaryButton:setX(actionX)
        self.chatPrimaryButton:setY(self.clientY + u(120))
        self.chatPrimaryButton:setWidth(u(72))
    end
    if self.chatSecondaryButton then
        self.chatSecondaryButton:setX(actionX)
        self.chatSecondaryButton:setY(self.clientY + u(86))
        self.chatSecondaryButton:setWidth(u(72))
    end
    if self.chatForgotButton then
        self.chatForgotButton:setX(fieldX)
        self.chatForgotButton:setY(self.clientY + u(154))
        self.chatForgotButton:setWidth(u(144))
    end
    if self.chatResetPasswordButton then
        self.chatResetPasswordButton:setX(actionX - u(44))
        self.chatResetPasswordButton:setY(self.clientY + u(86))
        self.chatResetPasswordButton:setWidth(u(116))
    end
    if self.chatLogoutButton then
        self.chatLogoutButton:setX(self.clientX + self.clientW - u(86))
        self.chatLogoutButton:setY(self.clientY + u(12))
        self.chatLogoutButton:setWidth(u(78))
    end
    if self.chatAddButton then
        self.chatAddButton:setX(self.clientX + u(10))
        self.chatAddButton:setY(self.clientY + u(12))
        self.chatAddButton:setWidth(u(60))
    end
    if self.chatAcceptButton then
        self.chatAcceptButton:setX(self.clientX + u(76))
        self.chatAcceptButton:setY(self.clientY + u(12))
        self.chatAcceptButton:setWidth(u(68))
    end
    if self.chatCancelButton then
        self.chatCancelButton:setX(self.clientX + self.clientW - u(164))
        self.chatCancelButton:setY(self.clientY + u(12))
        self.chatCancelButton:setWidth(u(70))
    end
    if self.chatRequestEntry then
        self.chatRequestEntry:setX(self.clientX + u(84))
        self.chatRequestEntry:setY(self.clientY + u(40))
        self.chatRequestEntry:setWidth(self.clientW - u(176))
    end
    if self.chatRequestSendButton then
        self.chatRequestSendButton:setX(self.clientX + self.clientW - u(86))
        self.chatRequestSendButton:setY(self.clientY + u(40))
        self.chatRequestSendButton:setWidth(u(78))
    end
    if self.chatMessageEntry then
        self.chatMessageEntry:setX(self.clientX + u(196))
        self.chatMessageEntry:setY(self.clientY + self.clientH - u(70))
        self.chatMessageEntry:setWidth(self.clientW - u(284))
        self.chatMessageEntry:setHeight(u(54))
    end
    if self.chatSendButton then
        self.chatSendButton:setX(self.clientX + self.clientW - u(78))
        self.chatSendButton:setY(self.clientY + self.clientH - u(38))
        self.chatSendButton:setWidth(u(68))
    end
    if self.chatUserEntry then self.chatUserEntry:setVisible(needsLogin or recoveryMode) end
    if self.chatPasswordEntry then self.chatPasswordEntry:setVisible(needsLogin or recoveryMode) end
    if self.chatRecoveryEmailEntry then self.chatRecoveryEmailEntry:setVisible(needsLogin) end
    if self.chatPrimaryButton then self.chatPrimaryButton:setVisible(needsLogin) end
    if self.chatSecondaryButton then self.chatSecondaryButton:setVisible(needsLogin) end
    if self.chatForgotButton then self.chatForgotButton:setVisible(needsLogin) end
    if self.chatResetPasswordButton then self.chatResetPasswordButton:setVisible(recoveryMode) end
    if self.chatLogoutButton then self.chatLogoutButton:setVisible(chatVisible) end
    if self.chatAddButton then self.chatAddButton:setVisible(chatVisible) end
    if self.chatAcceptButton then self.chatAcceptButton:setVisible(chatVisible and self:getSelectedChatRequest() ~= nil) end
    if self.chatCancelButton then self.chatCancelButton:setVisible(requestMode) end
    if self.chatRequestEntry then self.chatRequestEntry:setVisible(requestMode) end
    if self.chatRequestSendButton then self.chatRequestSendButton:setVisible(requestMode) end
    if self.chatMessageEntry then self.chatMessageEntry:setVisible(chatVisible and self:getSelectedChatPartner() ~= nil) end
    if self.chatSendButton then self.chatSendButton:setVisible(chatVisible and self:getSelectedChatPartner() ~= nil) end
end

function target:setFolderEditControlsVisible(visible)
    local function u(value) return uiValue(self, value) end
    if self.folderNameEntry then
        self.folderNameEntry:setX(self.clientX + u(30))
        self.folderNameEntry:setY(self.clientY + u(74))
        self.folderNameEntry:setWidth(self.clientW - u(122))
    end
    if self.folderSaveButton then
        self.folderSaveButton:setX(self.clientX + self.clientW - u(82))
        self.folderSaveButton:setY(self.clientY + u(74))
        self.folderSaveButton:setWidth(u(72))
    end
    if self.folderCancelButton then
        self.folderCancelButton:setX(self.clientX + self.clientW - u(82))
        self.folderCancelButton:setY(self.clientY + u(106))
        self.folderCancelButton:setWidth(u(72))
    end
    if self.folderNameEntry then self.folderNameEntry:setVisible(visible) end
    if self.folderSaveButton then self.folderSaveButton:setVisible(visible) end
    if self.folderCancelButton then self.folderCancelButton:setVisible(visible) end
end

function target:setPostsControlsVisible(visible)
    local function u(value) return uiValue(self, value) end
    if self.postsNameEntry then
        self.postsNameEntry:setX(self.clientX + u(56))
        self.postsNameEntry:setY(self.clientY + u(34))
        self.postsNameEntry:setWidth(u(124))
        self.postsNameEntry:setVisible(visible)
    end
    if self.postsBodyEntry then
        self.postsBodyEntry:setX(self.clientX + u(10))
        self.postsBodyEntry:setY(self.clientY + u(64))
        self.postsBodyEntry:setWidth(self.clientW - u(92))
        self.postsBodyEntry:setHeight(u(36))
        self.postsBodyEntry:setVisible(visible)
    end
    if self.postsSendButton then
        self.postsSendButton:setX(self.clientX + self.clientW - u(76))
        self.postsSendButton:setY(self.clientY + u(34))
        self.postsSendButton:setWidth(u(66))
        self.postsSendButton:setVisible(visible)
    end
end

function target:setMarketControlsVisible(visible)
    local recoveryMode = visible and self.accountRecoveryService == "market"
    local loggedIn = visible and self:isMarketLoggedIn() and not recoveryMode
    local needsLogin = visible and not self:isMarketLoggedIn() and not recoveryMode
    local function u(value) return uiValue(self, value) end
    local fieldX = self.clientX + u(122)
    local actionX = self.clientX + self.clientW - u(84)
    if self.marketUserEntry then
        self.marketUserEntry:setX(fieldX)
        self.marketUserEntry:setY(self.clientY + u(76))
        self.marketUserEntry:setWidth(math.max(u(176), self.clientW - u(218)))
        self.marketUserEntry:setVisible(needsLogin or recoveryMode)
    end
    if self.marketPasswordEntry then
        self.marketPasswordEntry:setX(fieldX)
        self.marketPasswordEntry:setY(self.clientY + u(110))
        self.marketPasswordEntry:setWidth(math.max(u(176), self.clientW - u(218)))
        self.marketPasswordEntry:setVisible(needsLogin or recoveryMode)
    end
    if self.marketRecoveryEmailEntry then
        self.marketRecoveryEmailEntry:setX(fieldX)
        self.marketRecoveryEmailEntry:setY(self.clientY + u(144))
        self.marketRecoveryEmailEntry:setWidth(math.max(u(176), self.clientW - u(218)))
        self.marketRecoveryEmailEntry:setVisible(needsLogin)
    end
    if self.marketPrimaryButton then
        self.marketPrimaryButton:setX(actionX)
        self.marketPrimaryButton:setY(self.clientY + u(144))
        self.marketPrimaryButton:setWidth(u(72))
        self.marketPrimaryButton:setVisible(needsLogin)
    end
    if self.marketSecondaryButton then
        self.marketSecondaryButton:setX(actionX)
        self.marketSecondaryButton:setY(self.clientY + u(110))
        self.marketSecondaryButton:setWidth(u(72))
        self.marketSecondaryButton:setVisible(needsLogin)
    end
    if self.marketForgotButton then
        self.marketForgotButton:setX(fieldX)
        self.marketForgotButton:setY(self.clientY + u(178))
        self.marketForgotButton:setWidth(u(144))
        self.marketForgotButton:setVisible(needsLogin)
    end
    if self.marketResetPasswordButton then
        self.marketResetPasswordButton:setX(actionX - u(44))
        self.marketResetPasswordButton:setY(self.clientY + u(110))
        self.marketResetPasswordButton:setWidth(u(116))
        self.marketResetPasswordButton:setVisible(recoveryMode)
    end
    if self.marketShopButton then
        self.marketShopButton:setX(self.clientX + u(10))
        self.marketShopButton:setY(self.clientY + u(12))
        self.marketShopButton:setWidth(u(66))
        self.marketShopButton:setVisible(loggedIn)
    end
    if self.marketJobsButton then
        self.marketJobsButton:setX(self.clientX + u(82))
        self.marketJobsButton:setY(self.clientY + u(12))
        self.marketJobsButton:setWidth(u(66))
        self.marketJobsButton:setVisible(loggedIn)
    end
    if self.marketDebugMoneyButton then
        self.marketDebugMoneyButton:setX(self.clientX + u(150))
        self.marketDebugMoneyButton:setY(self.clientY + u(12))
        self.marketDebugMoneyButton:setWidth(u(76))
        self.marketDebugMoneyButton:setVisible(loggedIn and isDebugModeEnabled(self.playerObj))
    end
    if self.marketResetShopButton then
        self.marketResetShopButton:setX(self.clientX + u(230))
        self.marketResetShopButton:setY(self.clientY + u(12))
        self.marketResetShopButton:setWidth(u(76))
        self.marketResetShopButton:setVisible(loggedIn and isDebugModeEnabled(self.playerObj))
    end
    if self.marketResetJobsButton then
        self.marketResetJobsButton:setX(self.clientX + u(310))
        self.marketResetJobsButton:setY(self.clientY + u(12))
        self.marketResetJobsButton:setWidth(u(76))
        self.marketResetJobsButton:setVisible(loggedIn and isDebugModeEnabled(self.playerObj))
    end
    if self.marketLogoutButton then
        self.marketLogoutButton:setX(self.clientX + self.clientW - u(86))
        self.marketLogoutButton:setY(self.clientY + u(12))
        self.marketLogoutButton:setWidth(u(78))
        self.marketLogoutButton:setVisible(loggedIn)
    end
end

function target:getComputerUsername()
    local data = self:getComputerData()
    if not data then return "User" end
    if not data.ComputerModUsername or data.ComputerModUsername == "" then
        data.ComputerModUsername = "User"
    end
    return data.ComputerModUsername
end

function target:getComputerAvatar()
    local data = self:getComputerData()
    if not data then return 1 end
    local avatar = tonumber(data.ComputerModAvatar or 1) or 1
    if avatar < 1 or avatar > 6 then avatar = 1 end
    return avatar
end

function target:isMonthFirstDate()
    local data = self:getComputerData()
    return data and data.ComputerModMonthFirstDate == true
end

function target:updateDateFormatButton()
    if self.dateFormatButton then
        self.dateFormatButton:setTitle(self:isMonthFirstDate() and tr("Date: M/D") or tr("Date: D/M"))
    end
end

function target:setResetConfirmControlsVisible(visible)
    local function u(value) return uiValue(self, value) end
    if self.resetConfirmButton then
        self.resetConfirmButton:setX(self.clientX + math.floor((self.clientW - u(220)) / 2))
        self.resetConfirmButton:setY(self.clientY + u(154))
        self.resetConfirmButton:setWidth(u(126))
    end
    if self.resetCancelButton then
        self.resetCancelButton:setX(self.clientX + math.floor((self.clientW - u(220)) / 2) + u(140))
        self.resetCancelButton:setY(self.clientY + u(154))
        self.resetCancelButton:setWidth(u(86))
    end
    if self.resetConfirmButton then self.resetConfirmButton:setVisible(visible) end
    if self.resetCancelButton then self.resetCancelButton:setVisible(visible) end
end

function target:setInstallControlsVisible(visible)
    local function u(value) return uiValue(self, value) end
    if self.currentView == "INSTALLER" or self.currentView == "INSTALLING" then
        if self.installNextButton then
            self.installNextButton:setX(self.clientX + self.clientW - u(142))
            self.installNextButton:setY(self.clientY + self.clientH - u(30))
            self.installNextButton:setWidth(u(64))
        end
        if self.installCancelButton then
            self.installCancelButton:setX(self.clientX + self.clientW - u(70))
            self.installCancelButton:setY(self.clientY + self.clientH - u(30))
            self.installCancelButton:setWidth(u(64))
        end
    end
    if self.installNextButton then self.installNextButton:setVisible(visible) end
    if self.installCancelButton then self.installCancelButton:setVisible(visible) end
end

function target:setDownloadControlsVisible(visible)
    local function u(value) return uiValue(self, value) end
    local showGameButtons = visible and self.currentView == "BROWSER" and self.browserCurrentAddress == "knoxshare.bbs"
    local showDownloadButton = visible and self.currentView == "BROWSER" and (
        self.browserCurrentAddress == "knoxshare.bbs"
        or (ComputerModMagazineSites and ComputerModMagazineSites[self.browserCurrentAddress or ""] ~= nil)
        or (ComputerModVideoSites and ComputerModVideoSites[self.browserCurrentAddress or ""] ~= nil)
    )
    if self.browserDownloadButton then
        self.browserDownloadButton:setX(self.clientX + self.clientW - u(112))
        self.browserDownloadButton:setY(self.clientY + self.clientH - u(28))
    end
    if self.browserMediaButton then
        self.browserMediaButton:setX(self.clientX + self.clientW - u(112))
        self.browserMediaButton:setY(self.clientY + self.clientH - u(28))
    end
    if self.downloadSelectButtons then
        local layout = self.getDownloadGameListLayout and self:getDownloadGameListLayout() or nil
        for i = 1, #self.downloadSelectButtons do
            local button = self.downloadSelectButtons[i]
            if layout then
                local row = math.floor((i - 1) / layout.columns)
                local col = (i - 1) % layout.columns
                local visibleRow = row - layout.offset
                button:setX(layout.listX + col * (layout.buttonW + layout.gap))
                button:setY(layout.listY + visibleRow * layout.rowStep)
                button:setWidth(layout.buttonW)
                button:setHeight(layout.rowH)
                button:setVisible(showGameButtons and visibleRow >= 0 and visibleRow < layout.visibleRows)
            else
                button:setVisible(false)
            end
        end
    end
    if self.browserDownloadButton then self.browserDownloadButton:setVisible(showDownloadButton) end
    if self.minimizeButton then self.minimizeButton:bringToTop() end
    if self.backButton then self.backButton:bringToTop() end
end

function target:openPasswordPanel()
    self.currentView = "PASSWORD"
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
    self:setPasswordControlsVisible(true)
    self:setResetConfirmControlsVisible(false)
    self:setInstallControlsVisible(false)
    self.backButton:setVisible(true)
    self.closeButton:setVisible(false)
    if self.passwordEntry then
        self.passwordEntry:setText("")
        self.passwordEntry:bringToTop()
    end
    self.passwordErrorText = nil
    self.passwordErrorTimer = 0
    if self.passwordActionButton then
        self.passwordActionButton:setTitle(self:hasPassword() and tr("Change") or tr("Save"))
    end
    if self.passwordClearButton then
        self.passwordClearButton:setVisible(true)
    end
    if self.passwordResetButton then
        self.passwordResetButton:setVisible(false)
    end
    self:updateStartMenuButtons()
end

function target:openLockScreen()
    self.currentView = "LOCK"
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
    self:setPasswordControlsVisible(true)
    self:setResetConfirmControlsVisible(false)
    self:setInstallControlsVisible(false)
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    if self.passwordEntry then
        self.passwordEntry:setText("")
        self.passwordEntry:setVisible(self:hasPassword())
        self.passwordEntry:bringToTop()
    end
    self.passwordErrorText = nil
    self.passwordErrorTimer = 0
    if self.passwordActionButton then
        self.passwordActionButton:setTitle(self:hasPassword() and tr("Login") or tr("Enter"))
        self.passwordActionButton:setVisible(true)
    end
    if self.passwordClearButton then
        self.passwordClearButton:setVisible(false)
    end
    self.startMenuOpen = false
    self.settingsMenuOpen = false
    self:updateStartMenuButtons()
end

function target:showDesktopHome()
    self.currentView = "DESKTOP"
    self.currentFolderName = nil
    self.folderContextMenu = nil
    self.gameContextMenu = nil
    self:setDesktopShortcutsVisible(false)
    self.backButton:setVisible(false)
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setResetConfirmControlsVisible(false)
    self:setInstallControlsVisible(false)
    self.passwordErrorText = nil
    self.passwordErrorTimer = 0
    self.closeButton:setVisible(false)
    if self.minimizeButton then self.minimizeButton:setVisible(false) end
    self:updateStartMenuButtons()
end

function target:updateComputerWorldScreen(powerOn)
    if not self.computer then return end
    local data = self:getComputerData()
    if data and data.ComputerModNetworkTerminal == true then
        syncComputerScreenGlow(self.computer, false)
        return
    end
    local spriteName = getComputerSpriteName(self.computer)
    if not spriteName then
        syncComputerScreenGlow(self.computer, powerOn)
        return
    end
    local value = string.lower(tostring(spriteName))
    local nextSpriteName = nil
    if powerOn then
        nextSpriteName = computerScreenOnSprites[value]
    else
        nextSpriteName = computerScreenOffSprites[value]
    end
    if not nextSpriteName or nextSpriteName == spriteName then
        syncComputerScreenGlow(self.computer, powerOn)
        return
    end
    local changed = false
    if self.computer.setSpriteFromName then
        changed = pcall(function() self.computer:setSpriteFromName(nextSpriteName) end)
    elseif self.computer.setSprite and getSprite then
        local sprite = getSprite(nextSpriteName)
        if sprite then
            changed = pcall(function() self.computer:setSprite(sprite) end)
        end
    end
    if not changed then return end
    if self.computer.transmitUpdatedSpriteToClients then
        pcall(function() self.computer:transmitUpdatedSpriteToClients() end)
    end
    syncComputerScreenGlow(self.computer, powerOn)
end

function target:setComputerPowerOn(powerOn)
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModPowerOn = powerOn == true
    if not data.ComputerModPowerOn then
        data.ComputerModLastView = nil
        data.ComputerModWindowMinimized = nil
        data.ComputerModMinimizedWindows = nil
        data.ComputerModSessionUnlocked = nil
        data.ComputerModActiveDownloadGame = nil
        data.ComputerModActiveDownloadProgress = nil
        data.ComputerModActiveDownloadLastWorldAge = nil
    end
    self:updateComputerWorldScreen(data.ComputerModPowerOn == true)
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:saveSessionView()
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModPowerOn = true
    self:updateComputerWorldScreen(true)
    if self:isNetworkTerminal() then
        data.ComputerModLastView = "NETWORK_TERMINAL"
        data.ComputerModWindowMinimized = nil
        data.ComputerModMinimizedWindows = {}
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
        return
    end
    local view = self.currentView or "DESKTOP"
    if view == "BOOTING" or view == "BOOT_ERROR" or view == "HARDWARE_ERROR" or view == "BIOS" or view == "OS_SETUP" or view == "RESET_CONFIRM" or view == "RESETTING" or view == "INSTALLING" or view == "DISC_WIPE_CONFIRM" or view == "DISC_WIPING" then
        view = "DESKTOP"
    end
    data.ComputerModLastView = view
    data.ComputerModLastFolderName = self.currentFolderName
    data.ComputerModWindowMinimized = nil
    data.ComputerModMinimizedWindows = {}
    local windows = self:getMinimizedWindows()
    for i = 1, math.min(#windows, 3) do
        if windows[i] and windows[i].view then
            local entry = {view = windows[i].view, label = windows[i].label or self:getWindowTitleForView(windows[i].view), installGameId = windows[i].installGameId, installStep = windows[i].installStep, folderName = windows[i].folderName}
            if windows[i].view == "PAINT" then
                entry.paintKey = windows[i].paintKey
                entry.paintW = windows[i].paintW
                entry.paintH = windows[i].paintH
                entry.paintColor = windows[i].paintColor
                entry.paintCanvas = windows[i].paintCanvas
            end
            table.insert(data.ComputerModMinimizedWindows, entry)
        end
    end
    if view == "INSTALLER" then
        data.ComputerModLastInstaller = self.installGameId
    end
    if view == "PAINT" then
        data.ComputerModPaintSession = {paintKey = self.activePaintKey, paintW = self.paintCanvasW, paintH = self.paintCanvasH, paintColor = self.paintColor, paintCanvas = {}}
        for key, value in pairs(self.paintCanvas or {}) do
            data.ComputerModPaintSession.paintCanvas[key] = value
        end
    else
        data.ComputerModPaintSession = nil
    end
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
end

function target:resumePoweredSession()
    local data = self:getComputerData()
    if not data or data.ComputerModPowerOn ~= true then
        return
    end
    self:updateComputerWorldScreen(true)
    self:updateDownloadProgress()
    self.bootTimer = 60
    self.bootStep = 3
    local componentFailure = self.getComponentBootFailure and self:getComponentBootFailure() or nil
    if componentFailure then
        self:setComputerPowerOn(false)
        self:showHardwareFailure(componentFailure)
        self:updateStartMenuButtons()
        return
    end
    if self:isNetworkTerminal() then
        self.passwordUnlocked = true
        self:openNetworkTerminal()
        return
    end
    self.passwordUnlocked = data.ComputerModSessionUnlocked == true or not self:hasPassword()
    local view = data.ComputerModLastView or "DESKTOP"
    self.minimizedWindows = {}
    if type(data.ComputerModMinimizedWindows) == "table" then
        for i = 1, math.min(#data.ComputerModMinimizedWindows, 3) do
            local item = data.ComputerModMinimizedWindows[i]
            if item and item.view then
                table.insert(self.minimizedWindows, {view = item.view, label = item.label or self:getWindowTitleForView(item.view), installGameId = item.installGameId, installStep = item.installStep, folderName = item.folderName, paintKey = item.paintKey, paintW = item.paintW, paintH = item.paintH, paintColor = item.paintColor, paintCanvas = item.paintCanvas})
            end
        end
    elseif data.ComputerModWindowMinimized and view ~= "DESKTOP" then
        table.insert(self.minimizedWindows, {view = view, label = self:getWindowTitleForView(view)})
        view = "DESKTOP"
    end
    if not self:isOSInstalled() then
        self.minimizedWindows = {}
        self:showBootError()
        self:updateStartMenuButtons()
        return
    end
    if self:hasPassword() and not self.passwordUnlocked then
        self:openLockScreen()
    elseif view == "FILES" then
        self:startFiles()
    elseif view == "GAMES" then
        self:openGamesMenu()
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
    elseif view == "MARKET" then
        self:startMarket()
    elseif view == "PAINT" then
        self:startPaint()
        if type(data.ComputerModPaintSession) == "table" then
            self.activePaintKey = data.ComputerModPaintSession.paintKey
            self.paintCanvasW = data.ComputerModPaintSession.paintW or self.paintCanvasW
            self.paintCanvasH = data.ComputerModPaintSession.paintH or self.paintCanvasH
            self.paintColor = data.ComputerModPaintSession.paintColor or self.paintColor
            self.paintCanvas = {}
            if type(data.ComputerModPaintSession.paintCanvas) == "table" then
                for key, value in pairs(data.ComputerModPaintSession.paintCanvas) do
                    self.paintCanvas[key] = value
                end
            end
        end
    elseif view == "FOLDER" and data.ComputerModLastFolderName then
        self:openFolderView(data.ComputerModLastFolderName)
    else
        self:showDesktopHome()
    end
end

function target:clearComputerPassword()
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModPasswordEnabled = false
    data.ComputerModPassword = nil
    self.passwordUnlocked = true
    if self.computer.transmitModData then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    if self.passwordEntry then
        self.passwordEntry:setText("")
    end
    if self.passwordActionButton then
        self.passwordActionButton:setTitle(tr("Save"))
    end
end

function target:performComputerReset(discEjectedByServer)
    if self:isNetworkTerminal() then
        self.resetInProgress = false
        self.resetTimer = 0
        self:showError(tr("Network Recovery OS cannot be wiped."))
        self:openNetworkTerminal()
        return
    end
    local data = self:getComputerData()
    if not data then return end
    if data.ComputerModMountedCD and isClient and isClient() and discEjectedByServer ~= true then
        if self.resetWaitingForDiscEject then return end
        self.resetWaitingForDiscEject = true
        if ComputerModCDClient and ComputerModCDClient.requestEject and ComputerModCDClient.requestEject(self.playerObj, self.computer, "reset") then
            return
        end
        self.resetWaitingForDiscEject = false
        self.resetInProgress = false
        self.resetTimer = 0
        self:showError(tr("The CD drive operation failed."))
        return
    end
    if data.ComputerModMountedCD and (not isClient or not isClient()) and self.playerObj and self.playerObj.getInventory and self.playerObj:getInventory() and self.playerObj:getInventory().AddItem and (data.ComputerModMountedCDItem or gameDiscItems[data.ComputerModMountedCD]) then
        if returnDiscToPlayer then
            returnDiscToPlayer(self.playerObj, self.playerObj:getInventory(), data.ComputerModMountedCDItem or gameDiscItems[data.ComputerModMountedCD], data.ComputerModMountedCDLabel, data.ComputerModMountedCDContents)
        else
            local returnedDisc = addItemWithSavedName(self.playerObj:getInventory(), data.ComputerModMountedCDItem or gameDiscItems[data.ComputerModMountedCD], data.ComputerModMountedCDLabel)
            if returnedDisc and returnedDisc.getModData and type(data.ComputerModMountedCDContents) == "table" then
                local contents = {}
                for i = 1, #data.ComputerModMountedCDContents do
                    contents[#contents + 1] = data.ComputerModMountedCDContents[i]
                end
                returnedDisc:getModData().ComputerModDiscContents = contents
            end
        end
    end
    if isClient and isClient() and sendClientCommand then
        local player = self.playerObj or getPlayer()
        sendClientCommand(player, "ComputerModMail", "Logout", {})
        sendClientCommand(player, "ComputerModChat", "Logout", {})
        sendClientCommand(player, "ComputerModMarket", "Logout", {})
    end
    for i = 1, #ComputerModComponents.driveFields do data[ComputerModComponents.driveFields[i]] = nil end
    data.ComputerModMetaInitialized = true
    data.ComputerModMachineID = data.ComputerModMachineID or self:generateComputerID()
    data.ComputerModFolders = {}
    data.ComputerModInstalledGames = {}
    data.ComputerModMountedCD = nil
    data.ComputerModMountedCDItem = nil
    data.ComputerModMountedCDLabel = nil
    data.ComputerModMountedCDContents = nil
    data.ComputerModOSInstalled = false
    data.ComputerModPowerOn = false
    data.ComputerModLastView = nil
    data.ComputerModLastFolderName = nil
    data.ComputerModPasswordEnabled = false
    data.ComputerModPassword = nil
    data.ComputerModNotepadText = ""
    data.ComputerModNotepadInitialized = true
    data.ComputerModNotepadSeedRepairV1 = true
    data.ComputerModCalculatorDisplay = "0"
    data.ComputerModDownloadedInstallers = {}
    data.ComputerModDownloadedMagazines = {}
    data.ComputerModTrashEntries = {}
    data.ComputerModFolderContents = {}
    data.ComputerModFolderContentVersion = 3
    data.ComputerModUserFolders = {}
    data.ComputerModDesktopNotes = {}
    data.ComputerModPaintFiles = {}
    data.ComputerModPaintSpawnInitialized = true
    data.ComputerModDesktopFiles = {}
    data.ComputerModPaintSession = nil
    data.ComputerModHiddenDesktopItems = {}
    data.ComputerModActiveDownloadGame = nil
    data.ComputerModActiveDownloadProgress = nil
    data.ComputerModActiveDownloadLastWorldAge = nil
    data.ComputerModMailLoggedIn = false
    data.ComputerModMailSessionAddress = nil
    data.ComputerModMailAddress = nil
    data.ComputerModMailPassword = nil
    data.ComputerModMailMessages = nil
    data.ComputerModChatLoggedIn = false
    data.ComputerModChatSessionUser = nil
    data.ComputerModChatUsername = nil
    data.ComputerModChatPassword = nil
    data.ComputerModMarketSessionUser = nil
    data.ComputerModMarketMoney = nil
    data.ComputerModMarketPurchases = nil
    data.ComputerModMarketCompletedJobs = nil
    self.marketAccount = nil
    data.ComputerModFactoryReset = true
    data.ComputerModMuteMusic = false
    data.ComputerModUse24HourClock = false
    data.ComputerModMonthFirstDate = false
    data.ComputerModTextSize = 2
    data.ComputerModUsername = "User"
    data.ComputerModAvatar = 1
    data.ComputerModBackgroundPalette = 1
    data.ComputerModBrowserAddress = "knox-weather.net"
    ComputerModComponents.captureDriveData(data)
    self.lastSavedNoteText = ""
    self.activeNotepadKey = nil
    self.activeNotepadName = nil
    self:setNotepadText("")
    self.calculatorDisplay = "0"
    self.calculatorStoredValue = nil
    self.calculatorOperator = nil
    self:applyComputerTextSize()
    self.calculatorResetDisplay = false
    self.installInProgress = false
    self.installProgress = 0
    self.installGameId = nil
    self.passwordUnlocked = true
    self.resetInProgress = false
    self.resetWaitingForDiscEject = false
    self.resetTimer = 0
    self:updateComputerWorldScreen(false)
    if self.computer.transmitModData then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    if isClient and isClient() and sendClientCommand and self.computer then
        sendClientCommand(self.playerObj or getPlayer(), "ComputerModComputerData", "FactoryReset", {
            x = self.computer:getX(),
            y = self.computer:getY(),
            z = self.computer:getZ(),
            machineId = tostring(data.ComputerModMachineID or ""),
            computerType = tostring(data.ComputerModComputerType or "desktop"),
            driveId = tostring(data.ComputerModDriveID or "")
        })
    end
    if self.syncNotepadDataToServer then
        self:syncNotepadDataToServer()
    end
    self:showBootError()
    self:updateStartMenuButtons()
end

function target:resetComputerData()
    self.resetReturnView = self.currentView == "LOCK" and "LOCK" or "PASSWORD"
    self.currentView = "RESET_CONFIRM"
    if self.resetConfirmButton then self.resetConfirmButton:setTitle(tr("Confirm Reset")) end
    if self.resetCancelButton then self.resetCancelButton:setTitle(tr("Cancel")) end
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
    self:setResetConfirmControlsVisible(true)
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:confirmResetComputer()
    if self.currentView == "DISC_WIPE_CONFIRM" then
        self.currentView = "DISC_WIPING"
        self.discWipeInProgress = true
        self.discWipeTimer = 0
        self:setResetConfirmControlsVisible(false)
        self:updateStartMenuButtons()
        return
    end
    self.currentView = "RESETTING"
    self.resetInProgress = true
    self.resetTimer = 0
    self.folderContextMenu = nil
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
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:cancelResetComputer()
    if self.currentView == "DISC_WIPE_CONFIRM" then
        self:setResetConfirmControlsVisible(false)
        self:startFiles()
        return
    end
    self:setResetConfirmControlsVisible(false)
    if self.resetReturnView == "LOCK" then
        self:openLockScreen()
    elseif self.resetReturnView == "BIOS" then
        self:openBiosMenu()
    else
        self:openPasswordPanel()
    end
end

function target:openDiscWipeConfirm()
    if not self:getMountedDiscGame() then return end
    self.currentView = "DISC_WIPE_CONFIRM"
    self.discContextMenu = nil
    self.folderContextMenu = nil
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
    self.notepadEntry:setVisible(false)
    self.browserAddressEntry:setVisible(false)
    self.browserGoButton:setVisible(false)
    self.browserMediaButton:setVisible(false)
    self:setCalculatorButtonsVisible(false)
    self:setPasswordControlsVisible(false)
    self:setInstallControlsVisible(false)
    self:setResetConfirmControlsVisible(true)
    if self.resetConfirmButton then self.resetConfirmButton:setTitle(tr("Wipe CD")) end
    if self.resetCancelButton then self.resetCancelButton:setTitle(tr("Cancel")) end
    self.backButton:setVisible(false)
    self.closeButton:setVisible(false)
    self:updateStartMenuButtons()
end

function target:ejectMountedDisc()
    local data = self:getComputerData()
    if not data or not data.ComputerModMountedCD then return end
    self.discContextMenu = nil
    if isClient and isClient() then
        if self.cdEjectPending then return end
        if ComputerModCDClient and ComputerModCDClient.requestEject and ComputerModCDClient.requestEject(self.playerObj or getPlayer(), self.computer, "") then
            self.cdEjectPending = true
            return
        end
        self:showError(tr("IGUI_ComputerMod_CDActionFailed", "The CD drive operation failed."))
        return
    end
    local inventory = self.playerObj and self.playerObj.getInventory and self.playerObj:getInventory() or nil
    local discGame = self:getMountedDiscGame()
    local fullType = data.ComputerModMountedCDItem or gameDiscItems[discGame]
    local returnedDisc = returnDiscToPlayer and returnDiscToPlayer(self.playerObj, inventory, fullType, data.ComputerModMountedCDLabel, data.ComputerModMountedCDContents) or nil
    if not returnedDisc then
        self:showError(tr("IGUI_ComputerMod_CDActionFailed", "The CD drive operation failed."))
        return
    end
    data.ComputerModMountedCD = nil
    data.ComputerModMountedCDItem = nil
    data.ComputerModMountedCDLabel = nil
    data.ComputerModMountedCDContents = nil
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    playComputerUISound("ComputerCDEject", self.playerObj)
    self.fileNoticeText = tr("IGUI_ComputerMod_CDRemoved", "CD removed.")
    self.fileNoticeTimer = 150
    self:startFiles()
end

function target:performDiscWipe()
    local data = self:getComputerData()
    if not data or not data.ComputerModMountedCD then return end
    data.ComputerModMountedCD = "blank"
    data.ComputerModMountedCDItem = "ComputerMod.BlankCD"
    data.ComputerModMountedCDLabel = "Blank CD"
    data.ComputerModMountedCDContents = {}
    self.discWipeInProgress = false
    self.discWipeTimer = 0
    self.fileNoticeText = tr("The CD is now blank.")
    self.fileNoticeTimer = 150
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    self:startFiles()
end

function target:handlePasswordAction()
    local data = self:getComputerData()
    if not data or not self.passwordEntry or not self.passwordEntry.getText then return end
    local typed = tostring(self.passwordEntry:getText() or "")
    typed = string.gsub(typed, "^%s+", "")
    typed = string.gsub(typed, "%s+$", "")

    if self.currentView == "LOCK" then
        if not self:hasPassword() then
            self.passwordUnlocked = true
            data.ComputerModSessionUnlocked = true
            if self.computer then
                ComputerModComputerTypes.transmitData(self.computer)
            end
            self.passwordErrorText = nil
            self.passwordErrorTimer = 0
            self:showDesktopHome()
            return
        end
        if typed ~= "" and data.ComputerModPassword == typed then
            self.passwordUnlocked = true
            data.ComputerModSessionUnlocked = true
            if self.computer then
                ComputerModComputerTypes.transmitData(self.computer)
            end
            self.passwordErrorText = nil
            self.passwordErrorTimer = 0
            self:showDesktopHome()
        else
            self:showError(tr("Wrong password."))
        end
        return
    end

    if typed == "" then
        self:clearComputerPassword()
        return
    end

    data.ComputerModPasswordEnabled = true
    data.ComputerModPassword = typed
    data.ComputerModFactoryReset = false
    data.ComputerModSessionUnlocked = true
    self.passwordUnlocked = true
    if self.computer.transmitModData then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    if self.passwordActionButton then
        self.passwordActionButton:setTitle(tr("Change"))
    end
end

function target:startPasswordHack()
    local data = self:getComputerData()
    if not data or not self:hasPassword() then return end
    local requiredElectrical = self:getHackRequiredElectricalLevel()
    local currentElectrical = self:getElectricalSkillLevel()
    local remaining = self:getPasswordHackLockRemaining()
    if remaining > 0 then
        self:showError(tr("Hack locked:") .. " " .. tostring(math.ceil(remaining)) .. " " .. tr("hours left."))
        return
    end
    if not self:isHackDiscMounted() then
        self:showError(tr("Insert Password Hack CD."))
        return
    end
    if currentElectrical < requiredElectrical then
        self:showError(tr("Electrical") .. " " .. tostring(requiredElectrical) .. " " .. tr("required."))
        return
    end
    self.currentView = "PASSWORD_HACK"
    self.passwordHackHits = 0
    self.passwordHackLine = ZombRand(20) / 100
    self.passwordHackDirection = 1
    self.passwordHackTarget = 0.25 + (ZombRand(50) / 100)
    self.passwordHackSpeed = 0.026
    self.passwordErrorText = nil
    self.passwordErrorTimer = 0
    self:setPasswordControlsVisible(false)
    self:updateStartMenuButtons()
end

function target:failPasswordHack()
    local data = self:getComputerData()
    if data then
        data.ComputerModHackLockUntil = getComputerWorldAgeHours() + 12
        data.ComputerModSessionUnlocked = false
        if self.computer then
            ComputerModComputerTypes.transmitData(self.computer)
        end
    end
    self.passwordUnlocked = false
    self:openLockScreen()
    self:showError(tr("Hack failed. Locked for 12 hours."))
end

function target:completePasswordHack()
    local data = self:getComputerData()
    if not data then return end
    data.ComputerModPasswordEnabled = false
    data.ComputerModPassword = nil
    data.ComputerModHackLockUntil = nil
    data.ComputerModSessionUnlocked = true
    self.passwordUnlocked = true
    if self.computer then
        ComputerModComputerTypes.transmitData(self.computer)
    end
    self.passwordErrorText = nil
    self.passwordErrorTimer = 0
    self:showDesktopHome()
end

function target:handlePasswordHackSpace()
    if self.currentView ~= "PASSWORD_HACK" then return false end
    local line = self.passwordHackLine or 0
    local previous = self.passwordHackPreviousLine or line
    local targetValue = self.passwordHackTarget or 0.5
    local targetHalfWidth = 0.075
    local low = targetValue - targetHalfWidth
    local high = targetValue + targetHalfWidth
    local crossed = (previous <= high and line >= low) or (line <= high and previous >= low)
    if (line >= low and line <= high) or crossed then
        self.passwordHackHits = (self.passwordHackHits or 0) + 1
        if self.passwordHackHits >= 3 then
            self:completePasswordHack()
            return true
        end
        self.passwordHackTarget = 0.18 + (ZombRand(64) / 100)
        self.passwordHackSpeed = (self.passwordHackSpeed or 0.026) + 0.006
        return true
    end
    self:failPasswordHack()
    return true
end

function target:updatePasswordHack(timeStep)
    if self.currentView ~= "PASSWORD_HACK" then
        self.passwordHackSpaceWasDown = false
        return
    end
    self.passwordHackPreviousLine = self.passwordHackLine or 0
    local step = (self.passwordHackSpeed or 0.026) * math.max(1, timeStep or 1)
    self.passwordHackLine = (self.passwordHackLine or 0) + step * (self.passwordHackDirection or 1)
    if self.passwordHackLine >= 1 then
        self.passwordHackLine = 1
        self.passwordHackDirection = -1
    elseif self.passwordHackLine <= 0 then
        self.passwordHackLine = 0
        self.passwordHackDirection = 1
    end
    local actionDown = ComputerModGameInput and ComputerModGameInput.isDown and ComputerModGameInput.isDown(self, "action") or (isKeyDown and isKeyDown(Keyboard.KEY_SPACE))
    if actionDown and not self.passwordHackSpaceWasDown then
        self:handlePasswordHackSpace()
    end
    self.passwordHackSpaceWasDown = actionDown == true
end

end

