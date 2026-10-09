--------------------------------------------------------------------------------------------------
--		----	  |			  |			|		 |				|    --    |      ----			--
--		----	  |			  |			|		 |				|    --	   |      ----			--
--		----	  |		-------	   -----|	 ---------		-----          -      ----	   -------
--		----	  |			---			|		 -----		------        --      ----			--
--		----	  |			---			|		 -----		-------	 	 ---      ----			--
--		----	  |		-------	   ----------	 -----		-------		 ---      ----	   -------
--			|	  |		-------			|		 -----		-------		 ---		  |			--
--			|	  |		-------			|	 	 -----		-------		 ---		  |			--
--------------------------------------------------------------------------------------------------
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISInventoryPane"
require "ISUI/ISResizeWidget"
require "ISUI/ISMouseDrag"

require "defines"

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local BUTTON_HGT = FONT_HGT_SMALL + 6
local UI_BORDER_SPACING = 10
local UI_BUBBLE_SPACING = 5
local UI_BUBBLE_H_SPACING = 3

local function enableImgMenu(frame, img, sound, theme, limit)
	getSoundManager():playUISound("UIHighlightMainMenuItem")
	local menuVol = getSoundManager():getMusicVolume()
	local rdmPhoto = LSUtil.rdm_inst:random(0, limit)
	frame:setVisible(true)
	img.texture = getTexture("media/ui/screenshots/"..theme..tostring(rdmPhoto)..".png")
	img:setVisible(true)
	getSoundManager():setMusicVolume(0)
	--pauseSoundAndMusic()
	getSoundManager():playMusic(sound)
	return sound, menuVol, 1, {0,0,rdmPhoto}
end

local function disableImgMenu(frame, imgs, sound, oV)
	getSoundManager():stopMusic(sound)
	frame:setVisible(false)
	imgs[1]:setVisible(false)
	imgs[2]:setVisible(false)
	--pauseSoundAndMusic()
	getSoundManager():setMusicVolume(oV)
end

local function checkForRepeats(limit,lastImgDigits)
	local isRepeat, digit = false, LSUtil.rdm_inst:random(0, limit)
	for n=1, #lastImgDigits do
		if lastImgDigits[n] == digit then isRepeat = true; break; end
	end
	if isRepeat then
		for n=0, limit do
			local notRepeat = true
			for j=1, #lastImgDigits do
				if n == lastImgDigits[j] then notRepeat = false; end
			end
			if notRepeat then digit = n; break; end
		end
	end

	return digit
end

local function getNewDigitPos(digitPos)
	local newDigitPos = digitPos+1
	if newDigitPos > 3 then newDigitPos = 1; end
	return newDigitPos
end

local function getNewDigitTable(digit, digitPos, lastImgDigits)
	local digitTable = {}
	for n=1, 3 do
		local newDigit = (n ~= digitPos and lastImgDigits[n]) or digit
		digitTable[n] = newDigit
	end
	return digitTable
end

local function playNextImg(menuFocus, limit, menuTheme, lastImgDigits, digitPos)

	local digit = checkForRepeats(limit,lastImgDigits)
	local newDigitPos = getNewDigitPos(digitPos)
	local newDigitTable = getNewDigitTable(digit, newDigitPos, lastImgDigits)

	menuFocus.texture = getTexture("media/ui/screenshots/"..menuTheme..digit..".png")

	return newDigitTable, newDigitPos
end

local function getMusicPiece(oldSound, theme)
	local musicTable
	if theme == "home" then
		musicTable = {"Piano05AboutStrange","Piano05Etude","Piano10ChildrensCorner","Piano09PreludeInF","Piano06WaltzInBbMajor","Piano06Waltz","Piano07PineAppleRag"}
	elseif theme == "art" then
		--musicTable = {"Violin07March","Violin09Etude","Violin08FourthSymphony","Violin06Humoresque","Violin10Romance","Violin05Sarabande","Violin06FolksySong"}
		musicTable = {"World5","World6","World11","World12","World13","World15","World17"}
	end
	if oldSound then
		for n=1, #musicTable do
			if musicTable[n] == oldSound then table.remove(musicTable, n); break; end
		end
	end
	local getSongIdx = LSUtil.rdm_inst:random(#musicTable)

	return musicTable[getSongIdx]
end

local function getBubbleData()
	local o = {}
	o.menuPlay = 0
	o.menuOV = 0
	o.menuTheme = "music"
	o.delayCount = 0
	o.delayTotal = 30
	o.lastImgDigits = {0,0,0}
	o.digitPos = 0
	o.soundName = false
    return o
end

local function setDiscoLogo(main)
	if main and not main.discoLogoChanged then
		if not main.inGame then
			main.logoTexture = getTexture("media/ui/PZ_Logo_Disco.png")
			getSoundManager():playUISound("UI_Artwork_New")
		end
		main.discoLogoChanged = true
	end
end

local setupPortraitClick = function(self, bubble)
	getSoundManager():playUISound("UISelectListItem")
	if bubble.clickNum and bubble.clickNum > 100 then return; end
	bubble.clickNum = (bubble.clickNum and bubble.clickNum+1) or 0
	if bubble.clickNum > 10 then
		bubble.clickNum = 101
		bubble.texture = getTexture("media/ui/bubbles/bubble_ee.png")
		local sound = getSoundManager():playUISound("UI_Painting_Complete")
		getSoundManager():getUIEmitter():setVolume(sound, 10)
	end
end

local function setupGravity(self, bubble)
	bubble.gravityActive = false
	bubble.dragging = false
	bubble.grounded = false
	bubble.fx = bubble:getX()
	bubble.fy = bubble:getY()
	bubble.vx = 1.2
	bubble.vy = 3
	bubble.gravity = 2.1
	bubble.airDrag = 0.992
	bubble.groundFriction = 0.95
	bubble.floorBounce = 0.66
	bubble.wallBounce = 0.85
	bubble.throwScale = 1 -- mouse throw strength
	bubble.hitCooldown = 0
	bubble.cooldownBase = 3
	bubble.mouseVX = 0
	bubble.mouseVY = 0
	bubble.lastMouseX = nil
	bubble.lastMouseY = nil
	bubble.dragOffsetX = 0
	bubble.dragOffsetY = 0
	bubble.shakeEnergy = 0
	bubble.shakeThreshold = 220
	bubble.shakeDecay = 0.94
	bubble.prevMouseVX = 0
	bubble.prevMouseVY = 0
	function bubble:onclick()
		self.gravityActive = true
		self.grounded = false
		self.vx = 0
		self.vy = 0.5
		self.mouseVX = 0
		self.mouseVY = 0
		getSoundManager():playUISound("UI_WOOSH")
	end
	function bubble:onMouseDown(x, y)
		if not self.gravityActive then
			self:onclick()
		else
			getSoundManager():playUISound("UI_Button_SELECT_B")
		end
		self.dragging = true
		self.grounded = false
		self.vx = 0
		self.vy = 0
		self.mouseVX = 0
		self.mouseVY = 0
		self.lastMouseX = getMouseX()
		self.lastMouseY = getMouseY()
		self.dragOffsetX = x
		self.dragOffsetY = y
		return true
	end
	function bubble:onMouseUp(x, y)
		if self.dragging then
			self.dragging = false
			self.gravityActive = true
			self.grounded = false
			self.vx = (self.mouseVX or 0) * self.throwScale
			self.vy = (self.mouseVY or 0) * self.throwScale
			self.lastMouseX = nil
			self.lastMouseY = nil
		end
		return true
	end
end

local bubbles = {
	['music'] = {
		photos = 49,
		soundLoop = "GuitarAcoustic06MyOldKentuckyHomeLOOP",
		size = 30,
		row = 0,
		col = 0,
		spacing = {"after","music"},
	},
	['disco'] = {
		photos = 42,
		soundLoop = "slow4LOOP",
		size = 30,
		row = 1,
		col = 1,
		spacing = {"center","music","home"},
	},
	['home'] = {
		photos = 39,
		soundLoop = false,
		size = 30,
		row = 0,
		col = 1,
		spacing = {"after","music"},
	},
	['art'] = {
		photos = 23,
		soundLoop = false,
		size = 60,
		row = 0,
		col = 2,
		spacing = {"after","home"},
		onclick = setupPortraitClick,
	},
}

local function getBubbleX(bubble)
	return UI_BUBBLE_SPACING+(UI_BUBBLE_SPACING+30)*bubble.col
end

local ogFunc_instantiate = MainScreen.instantiate
function MainScreen:instantiate()
	ogFunc_instantiate(self)
	--if not self.inGame then
		local y = self.reportBug.y
		--y = y - UI_BORDER_SPACING - BUTTON_HGT
		
		self.bubbleData = getBubbleData()

		self.LSMenuScreenshotFrame = ISImage:new(self.reportBug.x-700, (self:getHeight() / 2) - 200, 0, 0, getTexture("media/ui/frame.png"))
		self.LSMenuScreenshotFrame:initialise()
		self:addChild(self.LSMenuScreenshotFrame)
		self.LSMenuScreenshotFrame:setVisible(false)
	
		self.LSMenuScreenshot = ISImage:new(self.reportBug.x-695, (self:getHeight() / 2) - 175, 0, 0, getTexture("media/ui/screenshots/music0.png"))
		self.LSMenuScreenshot.texture = getTexture("media/ui/screenshots/music0.png")
		self.LSMenuScreenshot:initialise()
		self:addChild(self.LSMenuScreenshot)
		self.LSMenuScreenshot:setVisible(false)

		self.LSMenuScreenshot2 = ISImage:new(self.reportBug.x-695, (self:getHeight() / 2) - 175, 0, 0, getTexture("media/ui/screenshots/disco0.png"))
		self.LSMenuScreenshot2.texture = getTexture("media/ui/screenshots/disco0.png")
		self.LSMenuScreenshot2:initialise()
		self:addChild(self.LSMenuScreenshot2)
		self.LSMenuScreenshot2:setVisible(false)

		for k, v in pairs(bubbles) do
			v.posY = -(bubbles[v.spacing[2]].size+UI_BUBBLE_H_SPACING)*v.row+(30-v.size)
			if v.spacing[1] == "center" then
				local bubbleA, bubbleB = bubbles[v.spacing[2]], bubbles[v.spacing[3]]
				v.posX = ((getBubbleX(bubbleA)+bubbleA.size+getBubbleX(bubbleB)+bubbleB.size)/2)-v.size
			elseif v.spacing[1] == "after" then
				v.posX = getBubbleX(v)
			end
			self['bubble_'..k] = ISImage:new(self.reportBug.x-(v.size+v.posX), y+v.posY, v.size, v.size, getTexture("media/ui/bubbles/bubble_"..k..".png"))
			self['bubble_'..k].autoScale = true
			self['bubble_'..k].backgroundColor = {r=1, g=1, b=1, a=0.7}
			self['bubble_'..k]:setMouseOverText(getText("UI_mainscreen_ls").." - "..getText("UI_mainscreen_ls_"..k))
			if v.onclick then
				self['bubble_'..k].target = self
				self['bubble_'..k].onclick = v.onclick
			end
			self['bubble_'..k]:initialise()
			self:addChild(self['bubble_'..k])
			if k == "disco" then setupGravity(self, self['bubble_'..k]); end
		end

	--end
end

local ogFunc_setBottomPanelVisible = MainScreen.setBottomPanelVisible
function MainScreen:setBottomPanelVisible(visible)
	ogFunc_setBottomPanelVisible(self, visible)
    if self.parent then
		for k, v in pairs(bubbles) do
			if self.parent['bubble_'..k] then self.parent['bubble_'..k]:setVisible(visible); end
		end
	end
end

local function updateGravity(main, bubble)
	if not bubble or not bubble.gravityActive then return; end
	local dt = 1
	if UIManager and UIManager.getMillisSinceLastRender then
		dt = math.min(2,math.max(0.5,UIManager.getMillisSinceLastRender()/16.6667))
	end

	if bubble.dragging and not isMouseButtonDown(0) then -- failsafe in case mouse was released outside bubble
		bubble.dragging = false
		bubble.gravityActive = true
		bubble.grounded = false
		bubble.vx = (bubble.mouseVX or 0) * bubble.throwScale
		bubble.vy = (bubble.mouseVY or 0) * bubble.throwScale
		bubble.lastMouseX = nil
		bubble.lastMouseY = nil
	end

	if bubble.hitCooldown and bubble.hitCooldown > 0 then -- avoid bounce sound spam
		bubble.hitCooldown = bubble.hitCooldown - 1
	end

	local maxX = main:getWidth() - bubble:getWidth()
	local maxY = main:getHeight() - bubble:getHeight() - 5

	if not bubble.fx then
		bubble.fx = bubble:getX()
		bubble.fy = bubble:getY()
	end

	if bubble.dragging then
		local mx = getMouseX()
		local my = getMouseY()

		if bubble.lastMouseX then
			local rawDX = mx - bubble.lastMouseX
			local rawDY = my - bubble.lastMouseY
			bubble.mouseVX = (bubble.mouseVX or 0) * 0.70 + (rawDX / dt) * 0.30
			bubble.mouseVY = (bubble.mouseVY or 0) * 0.70 + (rawDY / dt) * 0.30
			if not main.discoLogoChanged then
				local speed = math.abs(bubble.mouseVX) + math.abs(bubble.mouseVY)
				local turn = math.abs(bubble.mouseVX-(bubble.prevMouseVX or bubble.mouseVX))+math.abs(bubble.mouseVY-(bubble.prevMouseVY or bubble.mouseVY))
				bubble.shakeEnergy = (bubble.shakeEnergy or 0)*bubble.shakeDecay + (speed*0.03)+(turn*0.18)
				if bubble.shakeEnergy > bubble.shakeThreshold then
					setDiscoLogo(main)
					bubble.shakeEnergy = 0
				end
				bubble.prevMouseVX = bubble.mouseVX
				bubble.prevMouseVY = bubble.mouseVY
			end
		end

		bubble.lastMouseX = mx
		bubble.lastMouseY = my
		bubble.fx = math.max(0, math.min(mx - bubble.dragOffsetX, maxX))
		bubble.fy = math.max(0, math.min(my - bubble.dragOffsetY, maxY))
		bubble:setX(math.floor(bubble.fx + 0.5))
		bubble:setY(math.floor(bubble.fy + 0.5))
		return
	end

	bubble.vy = bubble.vy + (bubble.gravity * dt)
	bubble.fx = bubble.fx + (bubble.vx * dt)
	bubble.fy = bubble.fy + (bubble.vy * dt)
	bubble.vx = bubble.vx * math.pow(bubble.airDrag, dt)

	if bubble.fx < 0 then -- hit screen left side
		bubble.fx = 0
		bubble.vx = math.abs(bubble.vx) * bubble.wallBounce
		bubble.vy = bubble.vy * 0.98

		if bubble.hitCooldown <= 0 then
			getSoundManager():playUISound("UI_BOUNCE")
			bubble.hitCooldown = bubble.cooldownBase
		end

	elseif bubble.fx > maxX then -- hit screen right side
		bubble.fx = maxX
		bubble.vx = -math.abs(bubble.vx) * bubble.wallBounce
		bubble.vy = bubble.vy * 0.98

		if bubble.hitCooldown <= 0 then
			getSoundManager():playUISound("UI_BOUNCE")
			bubble.hitCooldown = bubble.cooldownBase
		end
	end

	if bubble.fy < 0 then -- hit ceiling
		bubble.fy = 0
		if bubble.vy < 0 then
			bubble.vy = math.abs(bubble.vy) * 0.25
		elseif math.abs(bubble.vy) > 2.5 and bubble.hitCooldown <= 0 then
			getSoundManager():playUISound("UI_BOUNCE")
			bubble.hitCooldown = bubble.cooldownBase
		end
	elseif bubble.fy >= maxY then -- hit floor
		bubble.fy = maxY

		if math.abs(bubble.vy) > 2.5 and bubble.hitCooldown <= 0 then
			local s = getSoundManager():playUISound("UI_BOUNCE")
			--getSoundManager():getUIEmitter():setVolume(s, 0.5)
			bubble.hitCooldown = bubble.cooldownBase
		end

		bubble.vy = -bubble.vy * bubble.floorBounce
		bubble.vx = bubble.vx * bubble.groundFriction

		if math.abs(bubble.vy) < 0.8 then
			bubble.vy = 0
		end
	end

	bubble:setX(math.floor(bubble.fx + 0.5))
	bubble:setY(math.floor(bubble.fy + 0.5))
end

local ogFunc_update = MainScreen.update
function MainScreen:update()
	ogFunc_update(self)
	if not self.inGame or self:isVisible() then
	--if not self.inGame and self.bubbleData then
	if self['bubble_disco'] then
		updateGravity(self, self['bubble_disco'])
	end
	if self.bubbleData then
		local mouseOverBubble
		for k, v in pairs(bubbles) do
			if self['bubble_'..k]:isMouseOver() then mouseOverBubble = k; break; end
		end
		if mouseOverBubble and self.bubbleData.menuPlay == 0 then
			self.bubbleData.menuTheme = mouseOverBubble
			if not bubbles[mouseOverBubble].soundLoop then
				self.bubbleData.soundName = getMusicPiece(self.bubbleData.soundName, mouseOverBubble)
			end
			self.bubbleData.menuPlay, self.bubbleData.menuOV, self.bubbleData.digitPos, self.bubbleData.lastImgDigits = enableImgMenu(self.LSMenuScreenshotFrame,self.LSMenuScreenshot, bubbles[mouseOverBubble].soundLoop or self.bubbleData.soundName,self.bubbleData.menuTheme,bubbles[mouseOverBubble].photos)
		elseif self.bubbleData.menuPlay ~= 0 then
			if not mouseOverBubble or mouseOverBubble ~= self.bubbleData.menuTheme then
				disableImgMenu(self.LSMenuScreenshotFrame,{self.LSMenuScreenshot,self.LSMenuScreenshot2},self.bubbleData.menuPlay,self.bubbleData.menuOV)
				self.bubbleData.menuPlay, self.bubbleData.delayCount, self.bubbleData.lastImgDigits, self.bubbleData.digitPos = 0, 0, {0,0,0}, 0
			else -- mouse is over loop
				if self.bubbleData.delayCount > self.bubbleData.delayTotal then
					self.bubbleData.delayCount = 0
					local menuFocus, limit = self.LSMenuScreenshot, bubbles[mouseOverBubble].photos
					if menuFocus and limit then self.bubbleData.lastImgDigits, self.bubbleData.digitPos = playNextImg(menuFocus, limit, self.bubbleData.menuTheme, self.bubbleData.lastImgDigits, self.bubbleData.digitPos); end
				else
					self.bubbleData.delayCount=self.bubbleData.delayCount+1
				end
				if not bubbles[mouseOverBubble].soundLoop and (not getSoundManager():isPlayingMusic() or self.bubbleData.menuPlay ~= getSoundManager():getCurrentMusicName()) then
					if getSoundManager():isPlayingMusic() then getSoundManager():stopMusic(getSoundManager():getCurrentMusicName()); end
					self.bubbleData.soundName = getMusicPiece(self.bubbleData.soundName, mouseOverBubble)
					getSoundManager():playMusic(self.bubbleData.soundName)
					self.bubbleData.menuPlay = self.bubbleData.soundName
				end
			end
		end
	end
	end
end

local ogFunc_onKeyRelease = MainScreen.onKeyRelease
function MainScreen:onKeyRelease(key)
    if self.inGame and self.bubbleData and self.bubbleData.menuPlay ~= 0 and not self:isVisible() and (getCore():isKey("Main Menu", key) or (getCore():getKey("Main Menu") == 0 and key == Keyboard.KEY_ESCAPE)) then
		disableImgMenu(self.LSMenuScreenshotFrame,{self.LSMenuScreenshot,self.LSMenuScreenshot2},self.bubbleData.menuPlay,self.bubbleData.menuOV)
		self.bubbleData.menuPlay, self.bubbleData.delayCount, self.bubbleData.lastImgDigits, self.bubbleData.digitPos = 0, 0, {0,0,0}, 0
	end
	ogFunc_onKeyRelease(self, key)
end