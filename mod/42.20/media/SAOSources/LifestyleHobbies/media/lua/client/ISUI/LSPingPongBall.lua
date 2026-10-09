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

LSPingPongBall = ISPanel:derive("LSPingPongBall")

local driftDistance = 0.5

local function hash01(n)
	local x = math.sin(n * 12.9898) * 43758.5453
	return x - math.floor(x)
end

function LSPingPongBall:updateRGB()
	local sqr = self.character and self.character:getSquare()
	local lightLevel = (sqr and sqr:getLightLevel(0)) or getWorld():getClimateManager():getDayLightStrength()
	local ambient = math.max(0.15, math.min(1, lightLevel))
	self.r, self.g, self.b = ambient, ambient, ambient
end

function LSPingPongBall:initialise()
	self:updateRGB()
end

function LSPingPongBall:close()
	self.shouldClose = true
	self:setVisible(false)
	self:removeFromUIManager()
end

function LSPingPongBall:setShot(shot)
	if not shot then return; end
	self.fromX, self.fromY = shot.fromX, shot.fromY
	self.toX, self.toY = shot.toX, shot.toY
	self.bounceX, self.bounceY = shot.bounceX, shot.bounceY
	if shot.z then self.z = shot.z; end
	self.t = math.max(0, shot.t or 0)
	self.endT = shot.endT or 1
	self.hasBounce = shot.hasBounce or false
	self.bounceT = shot.bounceT or 0.6
	self.dropped = shot.dropped or false
	self.wild = shot.wild or false
	self.alpha = shot.alpha or 1
	local variant = shot.variant
	if variant and variant ~= self.variant then
		self.variant = variant
		self.arcMul = 0.7 + hash01(variant) * 0.6 -- arc h
		self.lateralMul = (hash01(variant + 91.7) - 0.5) * 2 -- sideway drift
	end
end

function LSPingPongBall:prerender()

	--
end

function LSPingPongBall:render()
	if self.shouldClose or not self.texture or not self.fromX then return; end
	local zoomLvl = getCore():getZoom(self.playerNum)
	local t = self.t
	local peakArc = self.arcHeight * (self.arcMul or 1)
	local wx, wy, arc

	if self.hasBounce and self.bounceX then
		if t <= self.bounceT then
			-- first bigger arc
			local seg = (self.bounceT > 0) and math.max(0, t / self.bounceT) or 0
			wx = self.fromX + (self.bounceX - self.fromX) * seg
			wy = self.fromY + (self.bounceY - self.fromY) * seg
			arc = math.sin(math.min(1, seg) * math.pi) * peakArc
		else
			-- second
			local span = math.max(0.001, self.endT - self.bounceT)
			local seg = (t - self.bounceT) / span
			wx = self.bounceX + (self.toX - self.bounceX) * seg
			wy = self.bounceY + (self.toY - self.bounceY) * seg
			arc = math.sin(math.max(0, math.min(1, seg)) * math.pi) * peakArc * 0.4
		end
	else
		local seg = math.max(0, math.min(1, t))
		wx = self.fromX + (self.toX - self.fromX) * seg
		wy = self.fromY + (self.toY - self.fromY) * seg
		arc = math.sin(seg * math.pi) * peakArc
	end

	if self.dropped then
		local dx, dy = self.toX - self.fromX, self.toY - self.fromY
		local dlen = math.sqrt(dx*dx + dy*dy)
		if dlen > 0 then
			local driftAmount = (1 - (self.alpha or 1)) * driftDistance
			wx = wx + (-dy/dlen) * (self.lateralMul or 0) * driftAmount
			wy = wy + (dx/dlen) * (self.lateralMul or 0) * driftAmount
		end
	end

	local screenX, screenY = isoToScreenX(self.playerNum, wx, wy, self.z), isoToScreenY(self.playerNum, wx, wy, self.z)
	local overallT = math.max(0, math.min(1, (self.endT > 0) and (t / self.endT) or t))
	local lateral = (self.lateralMul or 0) * (self.wild and 26 or 10) * math.sin(overallT * math.pi)
	local flyDepthScale = 1 + (peakArc > 0 and (arc / peakArc) or 0) * 0.35
	local droppedness = self.dropped and (1 - (self.alpha or 1)) or 0
	arc = arc * (1 - droppedness)
	local depthScale = flyDepthScale + (0.55 - flyDepthScale) * droppedness
	local texW, texH = (self.texW/zoomLvl) * depthScale, (self.texH/zoomLvl) * depthScale
	local drawX = screenX - texW/2 + lateral/zoomLvl
	local drawY = screenY - texH/2 - arc/zoomLvl - (self.baseOffsetY/zoomLvl) * (1 - droppedness)
	self:drawTextureScaledAspect(self.texture, drawX, drawY, texW, texH, self.alpha or 1, self.r, self.g, self.b)
end

function LSPingPongBall:update()
	if self.shouldClose or not self.character or not self.character:hasTimedActions() then
		self:close()
		return
	end
	self:updateRGB()
end

function LSPingPongBall:new(character, texture, scale, arcHeight, baseOffsetY)
	local o = ISPanel:new(0, 0, 0, 0)
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.playerNum = character:getPlayerNum()
	o.texture = texture
	o.fromX, o.fromY, o.z = nil, nil, nil
	o.toX, o.toY = nil, nil
	o.bounceX, o.bounceY = nil, nil
	o.t = 0
	o.endT = 1
	o.hasBounce = false
	o.bounceT = 0.6
	o.arcMul = 1
	o.lateralMul = 0
	o.variant = nil
	o.dropped = false
	o.wild = false
	o.alpha = 1
	o.r, o.g, o.b = 1, 1, 1
	o.texW = (scale and scale[1]) or 16
	o.texH = (scale and scale[2]) or 16
	o.baseOffsetY = baseOffsetY or 48 -- lift the ball above the table/floor sprite, in pixels before zoom
	o.arcHeight = arcHeight or 24
	o.shouldClose = false
	o.name = nil
	o.backgroundColor = {r=0, g=0, b=0, a=0}
	o.borderColor = {r=0, g=0, b=0, a=0}
	o.width = 0
	o.height = 0
	o.anchorLeft = true
	o.anchorRight = true
	o.anchorTop = true
	o.anchorBottom = true
	return o
end
