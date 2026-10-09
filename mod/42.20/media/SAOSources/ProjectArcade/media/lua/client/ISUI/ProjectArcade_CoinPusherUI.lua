require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISImage"

ProjectArcade_CoinPusherUI = ISPanel:derive("ProjectArcade_CoinPusherUI")

require "ISUI/ISUIElement"

PADigitImage = ISUIElement:derive("PADigitImage")

function PADigitImage:initialise()
    ISUIElement.initialise(self)
end

function PADigitImage:render()
    if self.texture then
        self:drawTextureScaled(self.texture, 0, 0, self.width, self.height, 1, 1, 1, 1)
    end
end

function PADigitImage:setTex(tex)
    self.texture = tex
end

function PADigitImage:new(x, y, w, h, tex)
    local o = ISUIElement.new(self, x, y, w, h)
    o.texture = tex
    return o
end

local function _nowMs()
    if getTimestampMs then return getTimestampMs() end
    if UIManager and UIManager.getMillis then return UIManager.getMillis() end
    if getTimeInMillis then return getTimeInMillis() end
    return nil
end

function getDeltaSeconds(self)
    local ms = _nowMs()
    if ms then
        if not self._lastMs then
            self._lastMs = ms
            return 0
        end
        local dt = (ms - self._lastMs) / 1000
        self._lastMs = ms
        return dt
    end

    return 1/30
end

local function PA_CP_GetSfxVolMult()
    local pct = 100
    if SandboxVars and SandboxVars.ProjectArcade and SandboxVars.ProjectArcade.SfxVolumePct ~= nil then
        pct = tonumber(SandboxVars.ProjectArcade.SfxVolumePct) or 100
    end
    if pct < 0 then pct = 0 end
    if pct > 100 then pct = 100 end
    return pct / 100.0
end

local function PA_CP_PlayOneShotAtCharacter(character, soundName)
    if not character or not soundName then return end

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    e:setPos(character:getX(), character:getY(), character:getZ())

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        e:setVolume(id, 1.0 * PA_CP_GetSfxVolMult())
        e:set3D(id, true)
        e:tick()
    end
end

function ProjectArcade_CoinPusherUI:playSfx(soundName)
    PA_CP_PlayOneShotAtCharacter(self.playerObj, soundName)
end

local function setImgTexture(img, tex)
    if not img or not tex then return end

    if img.setImage then
        img:setImage(tex)
    elseif img.setTexture then
        img:setTexture(tex)
    else
        img.texture = tex
    end
end

local function countItemsRecurse(inv, fullType)
    if not inv or not fullType then return 0 end

    if inv.getCountTypeRecurse then
        return inv:getCountTypeRecurse(fullType) or 0
    end

    if inv.getItemCountRecurse then
        return inv:getItemCountRecurse(fullType) or 0
    end

    local items = inv.getItems and inv:getItems()
    if not items then return 0 end

    local c = 0
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it.getFullType and it:getFullType() == fullType then
            c = c + 1
        end
    end
    return c
end

local function isAnyMoveKeyDown()
    if not Keyboard or not isKeyDown then return false end
    return isKeyDown(Keyboard.KEY_W) or isKeyDown(Keyboard.KEY_A) or isKeyDown(Keyboard.KEY_S) or isKeyDown(Keyboard.KEY_D)
        or isKeyDown(Keyboard.KEY_UP) or isKeyDown(Keyboard.KEY_LEFT) or isKeyDown(Keyboard.KEY_DOWN) or isKeyDown(Keyboard.KEY_RIGHT)
end

local function clampNumber(n)
    n = tonumber(n) or 0
    if n < 0 then n = 0 end
    return math.floor(n)
end

function ProjectArcade_CoinPusherUI:initialise()
    ISPanel.initialise(self)
end

function ProjectArcade_CoinPusherUI:createChildren()
    ISPanel.createChildren(self)

	-- Contenedor
	
	self.texContainer = getTexture("media/ui/CoinPusher/ui_container.png")

	self.imgContainer = ISImage:new(0, 0, 952, 715, self.texContainer)
	self.imgContainer:initialise()
	self.imgContainer:instantiate()
	self:addChild(self.imgContainer)

    -- Texturas
    self.texSlotOn  = getTexture("media/ui/CoinPusher/coinslot.png")
    self.texSlotOff = getTexture("media/ui/CoinPusher/coinslot_off.png")
	self.texSlotHover = getTexture("media/ui/CoinPusher/slot_hover.png")

    self.texLv1   = getTexture("media/ui/CoinPusher/coinbanklv1.png")
    self.texLv2   = getTexture("media/ui/CoinPusher/coinbanklv2.png")
    self.texLv3   = getTexture("media/ui/CoinPusher/coinbanklv3.png")
    self.texLv4   = getTexture("media/ui/CoinPusher/coinbanklv4.png")
    self.texLv5   = getTexture("media/ui/CoinPusher/coinbanklv5.png")

    self.texWin   = getTexture("media/ui/CoinPusher/prize_win.png")
    self.texLose  = getTexture("media/ui/CoinPusher/prize_lose.png")
	self.texDoubt = getTexture("media/ui/CoinPusher/prize_doubt.png")


    self.numTex = {}
    for i=0,9 do
        self.numTex[i] = getTexture("media/ui/CoinPusher/cp_number_" .. tostring(i) .. ".png")
    end

    -- Layout
    local layoutShiftX = -25
	local layoutShiftY = 29
	local topY = 18 + layoutShiftY

    local slotW, slotH = 190, 22

    local bankW, bankH = 210, 270
    local gapX = 70

    local totalW = (bankW * 3) + (gapX * 2)
    local startX = math.floor((self.width - totalW) / 2) + layoutShiftX

    -- Botones de slots
    self.btnSlot = {}
	
	local BTN_W = 148
	local BTN_H = 23

	local slotShiftX = 30 
	local slotX1 = startX + (bankW - slotW)/2 + slotShiftX
	local slotX2 = startX + bankW + gapX + (bankW - slotW)/2 + slotShiftX
	local slotX3 = startX + (bankW*2) + (gapX*2) + (bankW - slotW)/2 + slotShiftX

    self.btnSlot[1] = ISButton:new(slotX1, topY, slotW, slotH, "", self, ProjectArcade_CoinPusherUI.onSlot1)
    self.btnSlot[2] = ISButton:new(slotX2, topY, slotW, slotH, "", self, ProjectArcade_CoinPusherUI.onSlot2)
    self.btnSlot[3] = ISButton:new(slotX3, topY, slotW, slotH, "", self, ProjectArcade_CoinPusherUI.onSlot3)

    for i=1,3 do
        local b = self.btnSlot[i]
        b:initialise()
        b:instantiate()
        b.borderColor.a = 0
        b.backgroundColor.a = 0
        b.backgroundColorMouseOver.a = 0
        b:setImage(self.texSlotOn)
        self:addChild(b)
		b:setImage(self.texSlotEnabled)
		b:setWidth(150)
		b:setHeight(25)
    end
	
	-- Textura del hover
self.texSlotHover = getTexture("media/ui/CoinPusher/slot_hover.png")

local function attachHoverImageToButton(parentUI, btn, tex, offX, offY, w, h)
    offX = offX or 0
    offY = offY or 0

    -- Hover
    w = w or btn.width

    local texW = (tex and tex.getWidth) and tex:getWidth() or 1
    local texH = (tex and tex.getHeight) and tex:getHeight() or 1
    h = h or math.floor((texH * (w / texW)) + 0.5)

    local hoverBtn = ISButton:new(btn.x + offX, btn.y + offY, w, h, "", parentUI, nil)
    hoverBtn:initialise()
    hoverBtn:instantiate()
    hoverBtn.borderColor.a = 0
    hoverBtn.backgroundColor.a = 0
    hoverBtn.backgroundColorMouseOver.a = 0
    hoverBtn:setVisible(false)
    hoverBtn:setImage(tex)

    function hoverBtn:onMouseUp(x, y)
        ISButton.onMouseUp(self, x, y)

        if btn and btn.isEnabled and (not btn:isEnabled()) then return true end
        if btn and btn.enable == false then return true end

        if btn and btn.onclick and btn.target then
            btn.onclick(btn.target, btn)
        end
        return true
    end

    parentUI:addChild(hoverBtn)
    if hoverBtn.bringToTop then hoverBtn:bringToTop() end

    btn._hoverBtn = hoverBtn

    function btn:onMouseMove(dx, dy)
        ISButton.onMouseMove(self, dx, dy)
        if self._hoverBtn then
            self._hoverBtn:setVisible(true)
            if self._hoverBtn.bringToTop then self._hoverBtn:bringToTop() end
        end
    end

    function btn:onMouseMoveOutside(dx, dy)
        ISButton.onMouseMoveOutside(self, dx, dy)
        if self._hoverBtn and (not self._hoverBtn.isMouseOver or not self._hoverBtn:isMouseOver()) then
            self._hoverBtn:setVisible(false)
        end
    end

    function hoverBtn:onMouseMove(dx, dy)
        ISButton.onMouseMove(self, dx, dy)
        self:setVisible(true)
        if self.bringToTop then self:bringToTop() end
    end
    function hoverBtn:onMouseMoveOutside(dx, dy)
        ISButton.onMouseMoveOutside(self, dx, dy)
        self:setVisible(false)
    end
end


	for i=1,3 do
		attachHoverImageToButton(self, self.btnSlot[i], self.texSlotHover, 0, 0, self.btnSlot[i].width, self.btnSlot[i].height)
	end

	
    -- Pozos
    local bankY = topY + slotH + 12

    self.imgBank1 = ISImage:new(startX, bankY, bankW, bankH, self.texLv3) -- grande: muy cargada
    self.imgBank2 = ISImage:new(startX + bankW + gapX, bankY, bankW, bankH, self.texLv2) -- medio
    self.imgBank3 = ISImage:new(startX + (bankW*2) + (gapX*2), bankY, bankW, bankH, self.texLv1) -- chico

    for _,img in ipairs({self.imgBank1, self.imgBank2, self.imgBank3}) do
        img:initialise()
        img:instantiate()
        self:addChild(img)
    end

	local digitsY = bankY + bankH + 250
	local digitW, digitH = 48, 60       

	self.prizeDigits = {}
	self.prizeDigits[1] = PADigitImage:new(startX + 30, digitsY, digitW, digitH, self.numTex[0])
	self.prizeDigits[2] = PADigitImage:new(startX + 30 + digitW + 8, digitsY, digitW, digitH, self.numTex[0])

	for _,img in ipairs(self.prizeDigits) do
		img:initialise()
		self:addChild(img)
	end

	self.totalDigits = {}
	local totalDigitsW = (digitW * 4) + (8 * 3)
	local totalDigitsX = math.floor((self.width - totalDigitsW) / 2) --+20

	for i=1,4 do
		local x = totalDigitsX + (i-1) * (digitW + 8)
		self.totalDigits[i] = PADigitImage:new(x, digitsY, digitW, digitH, self.numTex[0])
		self.totalDigits[i]:initialise()
		self:addChild(self.totalDigits[i])
	end


    -- Overlay resultado
	local overlayShiftX = -5
	local overlayShiftY = -25

	local ow = self.texWin and self.texWin:getWidth()  or self.width
	local oh = self.texWin and self.texWin:getHeight() or self.height

	local ox = math.floor((self.width - ow) / 2) + overlayShiftX
	local oy = math.floor((self.height - oh) / 2) + overlayShiftY

	self.resultOverlay = ISImage:new(ox, oy, ow, oh, self.texWin)
	self.resultOverlay:initialise()
	self.resultOverlay:instantiate()
	self.resultOverlay:setVisible(false)
	self:addChild(self.resultOverlay)


    -- Estado
    self.state = "idle"          
	self.awaitingServer = false
	self.awaitTimeout = 0
    self.slotsEnabled = true
    self.pendingReward = 0
    self.lastPrizeShown = 0

	self.doubtTimer = 0
	self._queuedResultTex = nil
	self._queuedDidWin = false
    self.resultTimer = 0         
    self.cooldownTimer = 0       

	self:setPrizeNumber(0)
	self:refreshCoinState()
	self:playSfx("PACPwelcome")
	self:setPitLevels({1,1,1})
	print("[CoinPusherUI] digitsY=", digitsY, "digitW=", digitW, "digitH=", digitH)
end

function ProjectArcade_CoinPusherUI:update()
    ISPanel.update(self)

    if self.closeOnMove and isAnyMoveKeyDown() then
        self:close()
        return
    end

    local dt = getDeltaSeconds(self)
    if not dt or dt <= 0 then dt = 1/60 end
    if dt > 0.25 then dt = 0.25 end
	
	if self.awaitingServer then
		self.awaitTimeout = (self.awaitTimeout or 0) - dt
		if self.awaitTimeout <= 0 then
			self.awaitingServer = false
			self.awaitTimeout = 0
			self.state = "idle"
			if self.refreshCoinState then
				self:refreshCoinState()
			else
				self:setSlotsEnabled(true)
			end
			return
		end
	end
	
	if self.state == "showingDoubt" then
    self.doubtTimer = (self.doubtTimer or 0) - dt

    if self.doubtTimer <= 0 then
			local tex = self._queuedResultTex or self.texLose
			setImgTexture(self.resultOverlay, tex)
			if self.resultOverlay then
				self.resultOverlay:setVisible(true)
				if self.resultOverlay.bringToTop then
					self.resultOverlay:bringToTop()
				end
			end

			self:playSfx(self._queuedDidWin and "PACPpayout" or "PACPlose")

			self.state = "showingResult"
			self.resultTimer = 3
		end

		return
	end


    if self.state == "showingResult" then
        self.resultTimer = (self.resultTimer or 0) - dt

        if self.resultTimer <= 0 then
            if self.resultOverlay then
                self.resultOverlay:setVisible(false)
            end

            if self.pendingReward and self.pendingReward > 0 then
                if self.onReward then
                    self.onReward(self.pendingReward)
                end
            end

            self:updateTotalCoins()
            self:setPrizeNumber(self.lastPrizeShown or 0)

            self.pendingReward = 0

            self.state = "cooldown"
            self.cooldownTimer = 1 -- tiempo para rehabilitar ranuras
        end

    elseif self.state == "cooldown" then
        self.cooldownTimer = (self.cooldownTimer or 0) - dt

        if self.cooldownTimer <= 0 then
            self.state = "idle"
            if self.refreshCoinState then
                self:refreshCoinState()
            else
                self:setSlotsEnabled(true) 
            end
			
			if self.slotsEnabled then
				self:playSfx("PACPreset")
			end
        end
    end
end


-- Slot click handlers
function ProjectArcade_CoinPusherUI:onSlot1()
    self:beginPlay(1)
end
function ProjectArcade_CoinPusherUI:onSlot2()
    self:beginPlay(2)
end
function ProjectArcade_CoinPusherUI:onSlot3()
    self:beginPlay(3)
end

function ProjectArcade_CoinPusherUI:beginPlay(pitId)
    if self.state ~= "idle" then return end

    self:refreshCoinState()

    if not self.hasCoins then
        self:close()
        return
    end

	if not self.slotsEnabled then return end

	self:playSfx("PACPinsertcoin")
	self:setSlotsEnabled(false)
	
	if self.isMpClient then
		self.awaitingServer = true
		self.awaitTimeout = 2.0
	else
		self.awaitingServer = false
		self.awaitTimeout = 0
	end


    if self.onPlay then
        self.onPlay(pitId)
    end
end

function ProjectArcade_CoinPusherUI:showResultOverlay(didWin, reward)
    self.lastPrizeShown = clampNumber(reward or 0)
    self.pendingReward  = clampNumber(reward or 0)

    self.awaitingServer = false
    self.awaitTimeout = 0

    local resultTex = (didWin and self.texWin) or self.texLose

    -- 10%: mostrar duda 2s antes
    local doDoubt = (ZombRand(100) < 10) and (self.texDoubt ~= nil)

    if doDoubt then
        setImgTexture(self.resultOverlay, self.texDoubt)
        if self.resultOverlay then
            self.resultOverlay:setVisible(true)
            if self.resultOverlay.bringToTop then
                self.resultOverlay:bringToTop()
            end
        end

        self:playSfx("PACPdoubt")

        self._queuedResultTex = resultTex
        self._queuedDidWin = didWin and true or false

        self.state = "showingDoubt"
        self.doubtTimer = 3
        return
    end

    setImgTexture(self.resultOverlay, resultTex)
    if self.resultOverlay then
        self.resultOverlay:setVisible(true)
        if self.resultOverlay.bringToTop then
            self.resultOverlay:bringToTop()
        end
    end

    self:playSfx(didWin and "PACPpayout" or "PACPlose")

    self.state = "showingResult"
    self.resultTimer = 3
end

function ProjectArcade_CoinPusherUI:setSlotsEnabled(enabled)
    self.slotsEnabled = enabled and true or false

    for i=1,3 do
        local b = self.btnSlot[i]
        if b then
            b:setEnable(self.slotsEnabled)
            b:setImage(self.slotsEnabled and self.texSlotOn or self.texSlotOff)
        end
    end
end

function ProjectArcade_CoinPusherUI:getBankTexture(pitId, level)
	self.bankTextures = self.bankTextures or {}

    pitId = tonumber(pitId) or 1
    level = tonumber(level) or 1

    if pitId < 1 then pitId = 1 end
    if pitId > 3 then pitId = 3 end
    if level < 1 then level = 1 end
    if level > 5 then level = 5 end

    self.bankTextures[pitId] = self.bankTextures[pitId] or {}

    if not self.bankTextures[pitId][level] then
        local path = string.format(
            "media/ui/CoinPusher/coinbank%d%s.png",
            pitId,
            "lv" .. level
        )
        self.bankTextures[pitId][level] = getTexture(path)
    end

    return self.bankTextures[pitId][level]
end

function ProjectArcade_CoinPusherUI:setPitLevels(levels)
    if not levels then levels = {1,1,1} end

    self.pitLevels = {
        tonumber(levels[1]) or 1,
        tonumber(levels[2]) or 1,
        tonumber(levels[3]) or 1,
    }

    setImgTexture(self.imgBank1, self:getBankTexture(1, self.pitLevels[1]))
    setImgTexture(self.imgBank2, self:getBankTexture(2, self.pitLevels[2]))
    setImgTexture(self.imgBank3, self:getBankTexture(3, self.pitLevels[3]))
end

function ProjectArcade_CoinPusherUI:markServerResponse()
    self.awaitingServer = false
    self.awaitTimeout = 0
end

function ProjectArcade_CoinPusherUI:setPrizeNumber(n)
    n = clampNumber(n)
    if n > 99 then n = 99 end

    local tens = math.floor(n / 10)
    local ones = n % 10

	if self.prizeDigits[1] then self.prizeDigits[1]:setTex(self.numTex[tens]) end
	if self.prizeDigits[2] then self.prizeDigits[2]:setTex(self.numTex[ones]) end
end

function ProjectArcade_CoinPusherUI:setTotalNumber(n)
    n = clampNumber(n)
    if n > 9999 then n = 9999 end

    local d4 = n % 10
    local d3 = math.floor(n / 10) % 10
    local d2 = math.floor(n / 100) % 10
    local d1 = math.floor(n / 1000) % 10

	if self.totalDigits[1] then self.totalDigits[1]:setTex(self.numTex[d1]) end
	if self.totalDigits[2] then self.totalDigits[2]:setTex(self.numTex[d2]) end
	if self.totalDigits[3] then self.totalDigits[3]:setTex(self.numTex[d3]) end
	if self.totalDigits[4] then self.totalDigits[4]:setTex(self.numTex[d4]) end
end

function ProjectArcade_CoinPusherUI:updateTotalCoins()
    if not self.playerObj or not self.playerObj.getInventory then
        self:setTotalNumber(0)
        return
    end

    local inv = self.playerObj:getInventory()
    if not inv then
        self:setTotalNumber(0)
        return
    end

    local fullType = self.currencyFullType or "Base.SilverCoin"
    local count = countItemsRecurse(inv, fullType)
	self:setTotalNumber(count)
end

function ProjectArcade_CoinPusherUI:close()
    self:setVisible(false)
    self:removeFromUIManager()
    if self.onClose then self.onClose() end
end

function ProjectArcade_CoinPusherUI:refreshCoinState()
    self:updateTotalCoins()

    local inv = self.playerObj and self.playerObj:getInventory()
    local fullType = self.currencyFullType or "Base.SilverCoin"
    local count = 0
    if inv then
        count = countItemsRecurse(inv, fullType)
    end

    self.hasCoins = (count >= (self.cost or 1))

    self:setSlotsEnabled(self.hasCoins and self.state == "idle")
end

function ProjectArcade_CoinPusherUI:new(x, y, width, height, playerObj, machineObj, currencyFullType, cost, onPlayFn, onRewardFn, onCloseFn)

    local o = ISPanel.new(self, x, y, width, height)
    o.playerObj = playerObj
    o.machineObj = machineObj
    o.currencyFullType = currencyFullType or "Base.SilverCoin"

    o.onPlay = onPlayFn      
    o.onReward = onRewardFn  
    o.onClose = onCloseFn
	o.cost = tonumber(cost) or 1

    o.closeOnMove = true

    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=1, g=1, b=1, a=0}

    o.anchorLeft = true
    o.anchorRight = true
    o.anchorTop = true
    o.anchorBottom = true
	
	o.bankTextures = {}
    return o
end
