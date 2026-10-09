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

require "ISUI/ISPanelJoypad"
require "Properties/Objects/beauty"

LSMoodleManager = LSMoodleManager or {}
LSBeautyScore = ISPanelJoypad:derive("LSBeautyScore");

local function doArtValueCalc(thisPlayer, artVal, beautyValue)
	if artVal == 0 or not SandboxVars.Text.DividerArt then return beautyValue; end
	local multiplier = SandboxVars.LSArt.ArtworkBeautyMultiplier or 1 -- sandbox option
	if CharacterTrait.HATESART and thisPlayer:hasTrait(CharacterTrait.HATESART) then return beautyValue-((artVal/4)*multiplier); 
	elseif thisPlayer:hasTrait(CharacterTrait.ARTISTIC) then return beautyValue+((artVal*1.5)*multiplier); end
	return beautyValue+(artVal*multiplier)
end

local function doTrashValueCalc(thisPlayer, val)
	if val == 0 or not SandboxVars.Text.DividerHygiene then return val; end
	if thisPlayer:hasTrait(CharacterTrait.SLOPPY) then val = val*0.5; elseif thisPlayer:hasTrait(CharacterTrait.CLEANFREAK) then val = val*3; end
	return val
end

local function getArtValue(Art, baseValue)
	if (not Art) or (not instanceof(Art, "IsoObject")) or (not Art:hasModData()) or (not Art:getModData().movableData) or (not Art:getModData().movableData['artBeauty']) then return baseValue; end
	--[[
	local facing = getFacing(Art)
	local attachedObj = getFullArt(Art, facing)
	local beautyVal = Art:getModData().movableData['artBeauty']
	if beautyVal ~= 0 and attachedObj then beautyVal = beautyVal/2; end
	return beautyVal
	]]--
	return Art:getModData().movableData['artBeauty']
end

local function getBeautyValue(thisPlayer, square, beautyValue)
	local trashValue, artValue = 0, 0
	for i = 0,square:getObjects():size()-1 do------------------------------------
		local object = square:getObjects():get(i)
		if object then
			local attachedsprite, objName, overlayName = object:getAttachedAnimSprite(), false, false		
			objName = object:getTextureName()
			if object:getOverlaySprite() then overlayName = object:getOverlaySprite():getName(); end
			if attachedsprite then
				for n=1,attachedsprite:size() do
					local sprite = attachedsprite:get(n-1)
					if sprite and sprite:getParentSprite() and sprite:getParentSprite():getName() then
						local newValue, isTrash, isArt = getBeautyProperty(sprite:getParentSprite():getName(), true)
						if isTrash then trashValue = trashValue+newValue;
						elseif not isArt then beautyValue = beautyValue+newValue; end
					end
				end
			end
			if objName then
				local newValue, isTrash, isArt = getBeautyProperty(objName, false)
				if isTrash then trashValue = trashValue+newValue;
				elseif isArt then artValue = artValue+getArtValue(object, newValue); 
				else beautyValue = beautyValue+newValue; end
			end
			if overlayName then
				local newValue, isTrash, isArt = getBeautyProperty(overlayName, true)
				if isTrash then trashValue = trashValue+newValue;
				elseif not isArt then beautyValue = beautyValue+newValue; end
			end
		end
	end

	trashValue = doTrashValueCalc(thisPlayer, trashValue)
	beautyValue = doArtValueCalc(thisPlayer, artValue, beautyValue)
	beautyValue = math.ceil(beautyValue+trashValue)
	return beautyValue
end

local function getRBGColors(val)
	local rgb = {0.9,0.9,0.9}
	local t = {
		{true,100,0,0.3,0},
		{true,50,0,0.5,0},
		{true,10,0.55,0.95,0.55},
		{false,-50,0.5,0,0},
		{false,-25,1,0,0},
		{false,-10,1,0.7,0.75},
	}
	for k, v in pairs(t) do
		if (v[1] and val >= v[2]) or (not v[1] and val <= v[2]) then
			rgb = {v[3],v[4],v[5]}
			break
		end
	end
	return rgb
end

local function canShowNegative(square, floorValue)
	if not square:isOutside() or floorValue >= 0 or SandboxVars.LSArt.BeautyShowNegative or SandboxVars.LSArt.BeautyOutdoors then return true; end
	return false
end

function LSBeautyScore:initialise()

	local square = getSquare(self.character:getX(), self.character:getY(), self.character:getZ())
	if not square then self:close(); end
	local sqrX, sqrY = square:getX(), square:getY()
	local mult = SandboxVars.LSArt.GeneralBeautyMultiplier or 1
	for x = sqrX-4, sqrX+4 do
		for y = sqrY-4, sqrY+4 do
			local newSqr = getCell():getOrCreateGridSquare(x, y, self.character:getZ())
			if newSqr and newSqr:IsOnScreen() and (newSqr:isOutside() == square:isOutside()) and (newSqr:getRoom() == square:getRoom()) then
				local thisFloor = newSqr:getFloor()
				if thisFloor then
					local floorValue = 0
					if newSqr:haveBlood() then floorValue = floorValue-(math.ceil(20*mult)); end
					if newSqr:getDeadBody() then floorValue = floorValue-(math.ceil(80*mult)); end
					if not self.floorList then self.floorList = {}; end
					floorValue = getBeautyValue(self.character, newSqr, floorValue)
					if canShowNegative(newSqr, floorValue) then
						local colorArgs = getRBGColors(floorValue)
						table.insert(self.floorList, {floorX=x,floorY=y,floorZ=thisFloor:getZ(),value=floorValue,rgb=colorArgs})
					end
				end
			end
		end
	end
	if not self.floorList then self:close(); end
	self.currentX = self.character:getX(); self.currentY = self.character:getY()
end

function LSBeautyScore:close()
	self:setVisible(false);
	self:removeFromUIManager();
	if LSMoodleManager then LSMoodleManager.BUIInstance = false; LSMoodleManager.BUIHovering = false; end
end

function LSBeautyScore:destroy(btn)
	self:setVisible(false);
	self:removeFromUIManager();
	if LSMoodleManager then LSMoodleManager.BUIInstance = false; LSMoodleManager.BUIHovering = false; end
end

function LSBeautyScore:prerender()

end

function LSBeautyScore:render()
	if not self.floorList then return; end
	for k, v in pairs(self.floorList) do
		self:drawText(tostring(v.value), isoToScreenX(self.character:getPlayerNum(), v.floorX, v.floorY, v.floorZ), isoToScreenY(self.character:getPlayerNum(), v.floorX, v.floorY, v.floorZ), v.rgb[1], v.rgb[2], v.rgb[3], 0.9, UIFont.Medium)
	end

end

function LSBeautyScore:update()
	--if self.character:getModData().LSMoodles["BeautyNeg"].Value == 0 and self.character:getModData().LSMoodles["BeautyGood"].Value == 0 then self:close(); end
	if self.fromMoodle then
		if self.character:getModData().LSMoodles["BeautyNeg"].Value == 0 and self.character:getModData().LSMoodles["BeautyGood"].Value == 0 then self:close(); end
	elseif not self.mainPanel or not self.mainPanel:isMouseOver() or not self.mainPanel:getIsVisible() then self:close(); end
	if not self.currentX or not self.currentY then return; end
	if self.currentX == self.character:getX() and self.currentY == self.character:getY() then return; end
	local square = getSquare(self.character:getX(), self.character:getY(), self.character:getZ())
	if not square then self:close(); end
	local sqrX, sqrY = square:getX(), square:getY()
	self.floorList = {}
	local mult = SandboxVars.LSArt.GeneralBeautyMultiplier or 1
	for x = sqrX-4, sqrX+4 do
		for y = sqrY-4, sqrY+4 do
			local newSqr = getCell():getOrCreateGridSquare(x, y, self.character:getZ())
			if newSqr and newSqr:IsOnScreen() and (newSqr:isOutside() == square:isOutside()) and (newSqr:getRoom() == square:getRoom()) then
				local thisFloor = newSqr:getFloor()
				if thisFloor then
					local floorValue = 0
					if newSqr:haveBlood() then floorValue = floorValue-(math.ceil(20*mult)); end
					if newSqr:getDeadBody() then floorValue = floorValue-(math.ceil(80*mult)); end
					floorValue = getBeautyValue(self.character, newSqr, floorValue)
					if canShowNegative(newSqr, floorValue) then
						local colorArgs = getRBGColors(floorValue)
						table.insert(self.floorList, {floorX=x,floorY=y,floorZ=thisFloor:getZ(),value=floorValue,rgb=colorArgs})
					end
				end
			end
		end
	end
	if not self.floorList then self:close(); end
	self.currentX = self.character:getX(); self.currentY = self.character:getY()
	ISPanelJoypad.update(self)
end

function LSBeautyScore:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)

end

function LSBeautyScore:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)

end

function LSBeautyScore:new(OgPanel, Player, Moodle) -- Player, Text, Type, Texture, ScreenTime, ClosePermanent, InfoPanel
	local o = {}
	local font = UIFont.NewSmall
	o = ISPanelJoypad:new(0, 0, 0, 0)
	setmetatable(o, self)
    self.__index = self
	o.mainPanel = OgPanel
    o.character = Player
	o.name = nil
    o.backgroundColor = {r=0, g=0.55, b=0.7, a=0}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=0}
	o.width = 0
	o.height = 0
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
	o.floorList = false
	o.currentX = false
	o.currentY = false
	o.fromMoodle = Moodle
	--o:noBackground()
    --o.new = new;
    return o;
end