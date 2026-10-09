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

LSTAOverlay = ISPanel:derive("LSTAOverlay");

local colorTable = {
	['darkYellow'] = {r=0.7,g=1,b=0,a=1},
	['lightBlue'] = {r=0.9,g=0.96,b=1,a=1},
	['lightGreen'] = {r=0.9,g=1,b=0.9,a=1},
	['lightOrange'] = {r=1,g=0.95,b=0.9,a=1},
	['lightPink'] = {r=1,g=0.9,b=1,a=1},
	['lightRed'] = {r=1,g=0.9,b=0.9,a=1},
	['lightYellow'] = {r=1,g=1,b=0.9,a=1},
	['orange'] = {r=1,g=0.5,b=0,a=1},
	['pink'] = {r=1,g=0.7,b=0.85,a=1},
	['yellow'] = {r=1,g=1,b=0,a=1},
	['white'] = {r=1,g=1,b=1,a=1},
}

local function copyColor(c)
	if not c then return nil end
	return { r = c.r, g = c.g, b = c.b, a = c.a }
end

function LSTAOverlay:getCurrentX()
	return self.offsetX
end

function LSTAOverlay:getX()
	return self.ogX
end

function LSTAOverlay:setX(num)
	if not num then return; end
	self.ogX = num
	self.offsetX = num
end

function LSTAOverlay:updateRGB()
	if self.ignoreDayLight then return; end
	if not self.square and self.coordX then self.square = getCell():getGridSquare(self.coordX,self.coordY,self.coordZ); end
	
	local lightLevel = (self.square and self.square:getLightLevel(0)) or getWorld():getClimateManager():getDayLightStrength()
	-- note to self - use getLightInfo in the future instead, better for colored lights
	--print("dayLight LEVEL IS "..tostring(dayLight))
	self.ambientLight = math.max(0.1, math.min(1, lightLevel))
	getPlayer():getSquare():getLightInfo(getPlayer():getPlayerNum())
	self.color.tex.r = math.min(1, math.max(0.05, self.ambientLight*self.color.tex.r))
	self.color.tex.g = math.min(1, math.max(0.05, self.ambientLight*self.color.tex.g))
	self.color.tex.b = math.min(1, math.max(0.05, self.ambientLight*self.color.tex.b))
end

function LSTAOverlay:resetOverlay(newTexture, animTable)
	if newTexture then self.texture = newTexture; end
	if self.fadeRate then self.color.tex.a = 1; end
	if self.offsetX ~= self.ogX then self.offsetX = self.ogX; end
	if self.offsetY ~= self.ogY then self.offsetY = self.ogY; end
	self.addW = 0
	self.addH = 0
	if self.animate then
		self.anim_Stop = false
		self.anim_delayEnd = false
		self.anim_Idx = 1
		self.anim_count = 0
	end
	self:updateRGB()
end

function LSTAOverlay:initialise()
	if getCore():getOptionUIRenderFPS() ~= 60 then getCore():setOptionUIRenderFPS(60); end
	self:updateRGB()
	if self.animate then
		self.anim_Idx = 1
		self.anim_count = 0
	end
end

function LSTAOverlay:close()
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSTAOverlay:destroy(btn)
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSTAOverlay:prerender()

end

function LSTAOverlay:render()
	if self.animate and self.animate.delay and not self.anim_delayEnd then return; end
	if self.color.tex.a > 0 and self.texture then
		local zoomLvl = getCore():getZoom(self.playerNum)
		--print("ZOOM LEVEL IS "..tostring(zoomLvl))
		local centerX, centerY = isoToScreenX(self.playerNum, self.coordX, self.coordY, self.coordZ)+self.offsetX/zoomLvl, isoToScreenY(self.character:getPlayerNum(), self.coordX, self.coordY, self.coordZ)+self.offsetY/zoomLvl
		
		if self.isTile then
			self.texture:RenderGhostTileColor(self.coordX, self.coordY, self.coordZ, self.offsetX*Core.getTileScale(), self.offsetY*Core.getTileScale(), self.color.tex.r, self.color.tex.g, self.color.tex.b, self.color.tex.a)
		else
			local texHeight, texWidth = (self.texH+self.addH)/zoomLvl, (self.texW+self.addW)/zoomLvl
			centerX,centerY=centerX-(texWidth/2)+(24/zoomLvl),centerY-(texHeight/2)-(8/zoomLvl)
			self:drawTextureScaledAspect(self.texture, centerX, centerY, texWidth, texHeight, self.color.tex.a, self.color.tex.r, self.color.tex.g, self.color.tex.b)
		end
	end

end

function LSTAOverlay:update()
	if self.shouldClose or not self.character or (self.isTA and not self.character:hasTimedActions()) or (self.animate and self.anim_Stop and self.animate.closeAfter) then
		self.shouldClose = true
		if self.fadeRate and self.color.tex.a > 0.05 then
			self.color.tex.a = self.color.tex.a-self.fadeRate
		else
			self:close()
		end
		return
	end
	if self.anim_count then
		self.anim_count = self.anim_count+1
		if self.animate.delay and not self.anim_delayEnd then
			if self.anim_count%self.animate.delay == 0 then
				self.anim_delayEnd = true
				self.anim_count = 0
			end
			return
		elseif not self.anim_Stop and self.animate.rate and self.anim_count%self.animate.rate == 0 then
			self.anim_Idx = (self.anim_Idx == #self.animate.tex and 1) or math.min(#self.animate.tex, math.floor(self.anim_Idx+1))
			if self.anim_Idx == 1 and not self.animate.loop then
				self.anim_Stop = true
			else
				local newTexture = getTexture(self.animate.tex[self.anim_Idx])
				self.texture = newTexture
			end
		elseif self.animate.movStop and self.anim_count%self.animate.movStop == 0 then
			self.moveX = false; self.moveY = false; self.animate.movStop = false;
		end
	end
	if self.fadeRate then
		self.color.tex.a = self.color.tex.a-self.fadeRate
	end
	if self.moveX then self.offsetX=self.offsetX+self.moveX; end
	if self.moveY then self.offsetY=self.offsetY+self.moveY; end
	if self.resizeX then self.addW=self.addW+self.resizeX; end
	if self.resizeY then self.addH=self.addH+self.resizeY; end
end

function LSTAOverlay:new(character, args, animate, colors, coords, scale) -- {font, text, texture, isTile, fadeRate, moveX, moveY, resizeX, resizeY, ignoreDayLight, isTA},  {delay=,closeAfter=,loop=,rate=,tex={}}, {text=textColor,tex=texColor}, {coordX, coordY, coordZ, offsetX, offsetY}, {width, height}
	local o = {}
	o = ISPanel:new(0, 0, 0, 0)
	setmetatable(o, self)
    self.__index = self
    o.character = character
	o.playerNum = character:getPlayerNum()
	o.font = args[1] or UIFont.NewSmall
	o.text = args[2]
	o.texture = args[3]
	o.isTile = args[4]
	o.fadeRate = args[5]
	o.moveX = args[6]
	o.moveY = args[7]
	o.resizeX = args[8]
	o.resizeY = args[9]
	o.animate = animate
	o.ignoreDayLight = args[10]
	o.isTA = args[11]
	o.color = {}
	o.color.text = (colors and colors.text) or (colors and colors.pickText and colorTable[colors.pickText]) or {r=0.7, g=0.7, b=0.7, a=1}
	o.color.tex = (colors and colors.tex) or (colors and colors.pickTex and copyColor(colorTable[colors.pickTex])) or {r=1, g=1, b=1, a=1}
	o.coordX = coords[1]
	o.coordY = coords[2]
	o.coordZ = coords[3]
	local x, y = coords[4] or 0, coords[5] or 0
	o.ogX = x
	o.ogY = y
	o.offsetX = x
	o.offsetY = y
	o.texW = (scale and scale[1]) or 64
	o.texH = (scale and scale[2]) or 64
	o.addW = 0
	o.addH = 0
	o.name = nil
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
	o.width = 0
	o.height = 0
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
	o.shouldClose = not o.isTA and not o.animate and o.fadeRate
    return o;
end