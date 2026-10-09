local env = _G.NMDeviceWindowEnv
setfenv(1, env)

function DeviceWindow:applyTopRowLayout(showBatterySlot, showHeadphoneSlot)
    local top = self:titleBarHeight() + EDGE_PAD
    local batteryX = EDGE_PAD + POWER_SIZE + MODULE_GAP
    local batteryY = top + math.floor((POWER_SIZE - BATTERY_SLOT_SIZE) / 2)
    local mediaY = top + math.floor((POWER_SIZE - MEDIA_SLOT_SIZE) / 2)
    local mediaX = showBatterySlot and (batteryX + BATTERY_SLOT_SIZE + MODULE_GAP) or batteryX
    local headphoneY = top + math.floor((POWER_SIZE - HEADPHONE_SLOT_SIZE) / 2)
    local headphoneX = mediaX + MEDIA_SLOT_SIZE + MODULE_GAP
    local fullLogoW, fullLogoH = NMNewMusicLogoDecoration.getSize()
    local compactLogoW, compactLogoH = NMNewMusicLogoDecoration.getCompactSize()
    local compactMode = (showBatterySlot == true and showHeadphoneSlot == true)
    local logoAnchorX = compactMode and (headphoneX + HEADPHONE_SLOT_SIZE + MODULE_GAP) or (mediaX + MEDIA_SLOT_SIZE + MODULE_GAP)
    local fullLogoY = top + math.floor((POWER_SIZE - fullLogoH) / 2)
    local compactLogoY = top + math.floor((POWER_SIZE - compactLogoH) / 2)

    if self.batterySlot then
        local btn = self.batterySlot.button
        local bar = self.batterySlot.bar
        if btn then
            btn:setX(batteryX)
            btn:setY(batteryY)
            btn:setVisible(showBatterySlot == true)
            btn.enable = (showBatterySlot == true)
        end
        if bar then
            bar:setX(batteryX)
            bar:setY(batteryY + BATTERY_SLOT_SIZE + 4)
            bar:setVisible(showBatterySlot == true)
        end
        if showBatterySlot ~= true and NMBatterySlot and NMBatterySlot.cancelExtractDrag then
            NMBatterySlot.cancelExtractDrag(self)
        end
    end

    if self.mediaSlot and self.mediaSlot.button then
        self.mediaSlot.button:setX(mediaX)
        self.mediaSlot.button:setY(mediaY)
    end

    if self.headphoneSlot and self.headphoneSlot.button then
        self.headphoneSlot.button:setX(headphoneX)
        self.headphoneSlot.button:setY(headphoneY)
        self.headphoneSlot.button:setVisible(showHeadphoneSlot == true)
        self.headphoneSlot.button.enable = (showHeadphoneSlot == true)
        if showHeadphoneSlot ~= true and NMHeadphoneSlot and NMHeadphoneSlot.cancelExtractDrag then
            NMHeadphoneSlot.cancelExtractDrag(self)
        end
    end

    if self.newMusicLogo then
        self.newMusicLogo:setX(logoAnchorX)
        self.newMusicLogo:setY(fullLogoY)
        self.newMusicLogo:setVisible(compactMode ~= true)
    end
    if self.newMusicLogoCompact then
        self.newMusicLogoCompact:setX(logoAnchorX)
        self.newMusicLogoCompact:setY(compactLogoY)
        self.newMusicLogoCompact:setVisible(compactMode == true)
    end

    self._nmShowBatterySlot = (showBatterySlot == true)
    self._nmShowHeadphoneSlot = (showHeadphoneSlot == true)
end

function DeviceWindow:refreshSlotVisibility()
    local resolved = self.resolveContextCached and self:resolveContextCached() or nil
    local profile = resolved and resolved.profile or nil
    if not profile and self.target and self.target.kind == "item" then
        local item = self.target.itemRef
        if item and NMDeviceProfiles and NMDeviceProfiles.getForItem then
            profile = NMDeviceProfiles.getForItem(item)
        end
    elseif not profile and self.target and self.target.kind == "vehicle" then
        local part = self.target.partRef
        if part and NMDeviceProfiles and NMDeviceProfiles.getVehicleProfile then
            profile = NMDeviceProfiles.getVehicleProfile(part)
        end
    end
    if not profile then
        return
    end
    self:applyTopRowLayout(
        NMDeviceProfiles.supportsBattery(profile) == true,
        NMDeviceProfiles.supportsHeadphones(profile) == true
    )
end

function DeviceWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    self:setResizable(true)
    self.resizable = true
    prewarmUIAssetsOnce()
    refreshFaderSize()
    refreshPaneSizes()

    local top = self:titleBarHeight() + EDGE_PAD
    self.powerBtn = NMPowerButton.attach(self, EDGE_PAD, top, POWER_SIZE)
    local batteryX = EDGE_PAD + POWER_SIZE + MODULE_GAP
    local batteryY = top + math.floor((POWER_SIZE - BATTERY_SLOT_SIZE) / 2)
    self.batterySlot = NMBatterySlot.attach(self, batteryX, batteryY, BATTERY_SLOT_SIZE)
    local mediaY = top + math.floor((POWER_SIZE - MEDIA_SLOT_SIZE) / 2)
    self.mediaSlot = NMMediaSlot.attach(self, batteryX + BATTERY_SLOT_SIZE + MODULE_GAP, mediaY, MEDIA_SLOT_SIZE)
    local headphoneX = batteryX + BATTERY_SLOT_SIZE + MODULE_GAP + MEDIA_SLOT_SIZE + MODULE_GAP
    local headphoneY = top + math.floor((POWER_SIZE - HEADPHONE_SLOT_SIZE) / 2)
    if NMHeadphoneSlot and NMHeadphoneSlot.attach then
        self.headphoneSlot = NMHeadphoneSlot.attach(self, headphoneX, headphoneY, HEADPHONE_SLOT_SIZE)
    else
        self.headphoneSlot = nil
    end
    local fullLogoX = headphoneX + HEADPHONE_SLOT_SIZE + MODULE_GAP
    local fullLogoY = top
    if NMNewMusicLogoDecoration and NMNewMusicLogoDecoration.attach then
        self.newMusicLogo = NMNewMusicLogoDecoration.attach(self, fullLogoX, fullLogoY)
    else
        self.newMusicLogo = nil
    end
    if NMNewMusicLogoDecoration and NMNewMusicLogoDecoration.attachCompact then
        self.newMusicLogoCompact = NMNewMusicLogoDecoration.attachCompact(self, fullLogoX, fullLogoY)
    else
        self.newMusicLogoCompact = nil
    end
    self:applyTopRowLayout(true, true)

    local stackX = EDGE_PAD
    local stackTop = top + POWER_SIZE + ROW_TO_READOUT_GAP
    self.readoutPane = NMReadoutPane.attach(self, stackX, stackTop)
    self.coverPane = NMCoverPane.attach(self, stackX, stackTop + READOUT_H + READOUT_TO_COVER_GAP)
    local transportY = stackTop + READOUT_H + READOUT_TO_COVER_GAP + COVER_H + COVER_TO_TRANSPORT_GAP
    self.transportRow = NMTransportButtonRow.attach(self, stackX, transportY)

    local faderX = self.width - EDGE_PAD - FADER_W
    local faderY = top
    self.volumeFader = NMVolumeFader.attach(self, faderX, faderY)
    if NMVolumeFader and NMVolumeFader.prewarm then
        NMVolumeFader.prewarm(self.volumeFader)
    end
end

