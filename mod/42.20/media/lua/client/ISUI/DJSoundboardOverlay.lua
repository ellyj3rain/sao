-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

LS_DJBooth = LS_DJBooth or {}
LS_DJBooth.buttons = LS_DJBooth.buttons or {}
LS_DJBooth.buttons.switch = LS_DJBooth.buttons.switch or {}
local dj_cache

DJSoundboardOverlay = ISPanelJoypad:derive("DJSoundboardOverlay")

function DJSoundboardOverlay:onRecordedLoop(num)
	if LS_DJBooth.failstate or not num then return; end
	self.buttons.bBL[num].active = true
	self.buttons.bBL[num].count = 0
	LS_DJBooth.keyPress(43+num)
	self:updateStatus(self.buttons.bBL[num])
end

local function resetSwitchLightIndicatorTex(parent)
	for k, v in pairs(parent.switchLight) do
		if not v.active then
			v.light.texture = dj_cache.sSI.off
		end
	end
end

local function doBigButtonLogic(bBtn, bBtime)
	local isActive = bBtn.active and not LS_DJBooth.failstate
	if bBtime then
		if isActive then
			if bBtn.count >= bBtn.total then
				bBtn.count = 0
				bBtn.active = false
				isActive = false
			else
				bBtn.count = bBtn.count+1
			end
		elseif bBtn.count > 0 then
			bBtn.count = 0
		end
	end
	local targetTex = (isActive and dj_cache.bB.on[bBtn.rgb]) or dj_cache.bB.off
	if bBtn.texture ~= targetTex then bBtn.texture = targetTex; end
	if bBtn.active ~= isActive then bBtn.active = isActive; end
end

function DJSoundboardOverlay:onMouseUpSwitch(x, y)
	if LS_DJBooth.failstate or self.parent.musicLevel < self.lvl then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end

	for k, v in pairs(self.parent.buttons.switch) do
		if self.idx ~= v.idx and v.idx ~= 5 then
			v.active = false
			self.parent.images["sSI"..tostring(v.idx)].active = false
			if v.texture ~= dj_cache.switch[v.internal].off then v.texture = dj_cache.switch[v.internal].off; end
			for j=1,#self.parent.buttons.sB do
				local sBtn = self.parent.buttons.sB[j]
				if sBtn.switch and sBtn.switch == v.idx then
					if sBtn.texture ~= dj_cache.sB.off then sBtn.texture = dj_cache.sB.off; end
					sBtn.active = false
				end
			end
		end
	end
	LS_DJBooth.keyPress(41)
	if self.active then
		self.active = false
		self.texture = dj_cache.switch[self.internal].off
		self.parent.images["sSI"..tostring(self.idx)].active = false
	else
		self.active = true
		self.texture = dj_cache.switch[self.internal].on
		self.parent.images["sSI"..tostring(self.idx)].active = true
	end
	getSoundManager():playUISound("JukeboxTurnOn")
end

function DJSoundboardOverlay:onMouseUpRecorder(x, y)
	if LS_DJBooth.failstate or self.parent.musicLevel < self.parent.buttons.switch[5].lvl then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end
	getSoundManager():playUISound("UI_Button_SELECT")
	local isSwitch = self.internal and self.internal == "b"
	if self.active then
		--self.active = false
		--if not isSwitch then self.parent.buttons.switch[5].active = false; end
		if isSwitch then self.active = false; else self.parent.buttons.switch[5].active = false; end
		return
	end
	if isSwitch then self.active = true; else self.parent.buttons.switch[5].active = true; end
	--if not isSwitch then self.parent.buttons.switch[5].active = true; end

	local all = self.parent.loopActive == 0 or self.parent.loopActive == 3
	local count, idx = 0, 1
	for n=1,3 do
		if all or n == self.parent.loopActive+1 then
			local str = tostring(n)
			self.parent["loopCount"..str] = count
			self.parent["loopCount"..str.."Total"] = 0
			idx = n
			if not all then break; end
		end
		count = count+1000
	end
	if all or idx == 1 then
		self.parent.buttons.sB[17].active = false
		self.parent.loopPlaying = false	
		self.parent.loopActive = 1
		self.parent.loopTable = {}
		self.parent.images["sSI5"].active = true
		self.parent.images["sSI6"].active = false
		self.parent.images["sSI7"].active = false
	else
		if idx == 2 then self.parent.images["sSI6"].active = true; elseif idx == 3 then self.parent.images["sSI7"].active = true; end
		self.parent.loopActive = idx
	end
	self.parent.loop = true
end

local function getCustomName(object, cName)
	if not object then return false; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("CustomName") and (properties:get("CustomName") == cName) then
        return true
    end
    return false
end

local function hasActiveData(obj)
	if obj:getModData().DFOnOff and obj:getModData().IsMainDF and
	obj:getModData().DFOnOff == "on" then return true; end
	return false
end

local function setDFMLight(object)
	for x = object:getX()-8,object:getX()+8 do
		for y = object:getY()-8,object:getY()+8 do
			local square = getCell():getGridSquare(x,y,object:getZ());
			if square then
				for i = 0,square:getObjects():size()-1 do
					local newObject = square:getObjects():get(i);
					if newObject and instanceof(newObject, "IsoObject") then
						if getCustomName(newObject, "Disco Floor") and hasActiveData(newObject) then
							newObject:getModData().MainLight = 0
							--newObject:transmitModData()
							sendClientCommand("LS", "ModifyObjData", {{newObject:getX(),newObject:getY(),newObject:getZ(),newObject:getSprite():getName()}, false, newObject:getModData()})
							return
						end
					end
				end
			end
		end
	end
end

DJSoundboardOverlay.onMouseUpSwitchLightAll = function(parent, num, tex)
	if (not parent.switchLight[num].active) and (parent.switchLightDelay <= 0) and parent.switchLightInteract then
		for k, v in pairs(parent.switchLight) do
			if v.active then
				v.active = false
				if v.texture == dj_cache.switchLightTex.onL then 
					v.texture = dj_cache.switchLightTex.offL;
				else v.texture = dj_cache.switchLightTex.offR; end
			end
			v.light.texture = dj_cache.sSI.red
		end
		parent.switchLight[num].active = true
		parent.switchLight[num].texture = tex
		parent.switchLight[num].light.texture = dj_cache.sSI.on
		parent.djbooth:getModData().LightStyle = parent.switchLight[num].style
		--print("onMouseUpSwitchLightAll style IS: "..parent.switchLight[num].style)
		--parent.djbooth:transmitModData()
		sendClientCommand("LS", "ModifyObjData", {{parent.djbooth:getX(),parent.djbooth:getY(),parent.djbooth:getZ(),parent.djbooth:getSprite():getName()}, false, parent.djbooth:getModData()})
		setDFMLight(parent.djbooth)
		getSoundManager():playUISound("UI_Button_SELECT")
		parent.switchLightDelay = 100
	else
		getSoundManager():playUISound("UI_DJBooth_ERROR")
	end
end

function DJSoundboardOverlay:onMouseUpSwitchLight(x, y)
	if LS_DJBooth.failstate then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end
	self.parent.onMouseUpSwitchLightAll(self.parent, self.key, dj_cache.switchLightTex["on"..self.texPos])
end

function DJSoundboardOverlay:onMouseUpVynil(x, y)
	if LS_DJBooth.failstate then return; end
	LS_DJBooth.keyPress(79)
	local newPhase = (self.phase == "1" and "2") or "1"
	self.phase = newPhase
	self.texture = dj_cache.vynil[self.internal..self.phase]
end

function DJSoundboardOverlay:onMouseUpStartLoop(x, y)
	if LS_DJBooth.failstate then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end

	if (not self.parent.loop and self.parent.loopActive == 1) or self.parent.loopActive > 1 then
		local current = self.parent.loopPlaying
		self.active = not current
		self.parent.loopPlaying = not current
		self.parent.loopCount1 = 0
		if self.parent.loop and self.parent.loopActive == 3 then
			self.parent.loopCount2 = 1000
		elseif not self.parent.loop then
			self.parent.loopCount2 = 1000
			self.parent.loopCount3 = 2000
		end
		self.parent.buttons.sB[1].active = false
		getSoundManager():playUISound("JukeboxTurnOff")
		self.parent:updateStatus(self)
	else
		getSoundManager():playUISound("UI_DJBooth_ERROR")
	end
end

function DJSoundboardOverlay:onMouseUpStopLoop(x, y)
	if LS_DJBooth.failstate then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end
	self.active = true
	LS_DJBooth.keyPress(self.kP)
	self.parent.loopActive = 0
	self.parent.loopPlaying = false
	self.parent.loop = false
	self.parent.buttons.switch[5].active = false
	self.parent.buttons.switch[5].texture = dj_cache.switch.b.off
	for k, v in pairs(self.parent.buttons.sB) do
		if v.internal ~= self.internal then
			v.active = false
		end
	end
	self.parent.buttons.sB[17].active = false
	self.parent.images["sSI5"].active = false
	self.parent.images["sSI6"].active = false
	self.parent.images["sSI7"].active = false
	getSoundManager():playUISound("JukeboxTurnOff")
	self.parent:updateStatus(self)
end

function DJSoundboardOverlay:onMouseUpSmallButton(x, y)
	if LS_DJBooth.failstate or not self.parent.buttons.switch[self.switch].active then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end
	self.active = true
	LS_DJBooth.keyPress(self.kP)
	for k, v in pairs(self.parent.buttons.sB) do
		if v.kP and v.internal ~= self.internal then
			v.active = false
		end
	end
	self.parent:updateStatus(self)
end

function DJSoundboardOverlay:onMouseUpBigButtonRight(x, y)
	if LS_DJBooth.failstate or self.active then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end
	self.active = true
	self.count = 0
	LS_DJBooth.keyPress(self.kP)
	self.parent:updateStatus(self)
end

function DJSoundboardOverlay:onMouseUpBigButtonLeft(x, y)
	if LS_DJBooth.failstate then getSoundManager():playUISound("UI_DJBooth_ERROR"); return; end
	LS_DJBooth.keyPress(self.kP)
	if self.parent.loop then
		self.parent.loopKey = self.idx
	end
	self.active = true
	self.count = 0
	self.parent:updateStatus(self)
end

local dj_uiParams = {}
dj_uiParams.arrows = {
	[1] = {22,20,15,26,">","RIGHTLEFT"},
    [2] = {-37,20,15,26,"<","RIGHTLEFT"},
	[3] = {-17,18,35,12,"^","UP"},
	[4] = {-17,38,35,12,"v","DOWN"}
}
dj_uiParams.vynils = {
	[1] = {-430,-90,220,290,"a"},
    [2] = {210,-90,220,290,"b"}
}
dj_uiParams.switch = {
	[1] = {-118,60,35,60,"a",2},
    [2] = {-51,60,35,60,"a",4},
	[3] = {15,60,35,60,"a",6},
	[4] = {82,60,35,60,"a",8},
	[5] = {-18,-80,36,36,"b",5,"UI_DJBooth_LoopRecord"}
}

dj_uiParams.sB = {
	{-115,-140,12,13,false,"UI_DJBooth_StopLoop",41},
    {-65,-140,12,13,1,"A",2},
	{-45,-140,12,13,1,"B",3},
	{-25,-140,12,13,1,"C",4},
    {35,-140,12,13,2,"A",5},
	{55,-140,12,13,2,"B",6},
	{75,-140,12,13,2,"C",7},
	{95,-140,12,13,2,"D",8},
	{-85,-110,12,13,3,"A",9},
	{-65,-110,12,13,3,"B",10},
	{-45,-110,12,13,3,"C",11},
	{-25,-110,12,13,3,"D",12},
	{35,-110,12,13,4,"A",19},
	{55,-110,12,13,4,"B",20},
	{75,-110,12,13,4,"C",21},
	{95,-110,12,13,4,"D",22},
	{-63,10,12,13,false,"UI_DJBooth_CustomLoop"}
}

dj_uiParams.bBR = {
	{70,5,7,80,"Rewind"},
    {100,5,7,81,"Woosh"},
	{38,-25,6,75,"Impact"},
	{68,-25,15,76,"Crowd"},
    {98,-25,10,77,"War"},
	{36,-55,6,71,"Synth"},
	{66,-55,10,72,"Airhorn"},
	{96,-55,8,73,"Sirens"}
}

dj_uiParams.bBL = {
	{-100,5,44,"ElecKickdrum"},
    {-130,5,45,"Kickdrum"},
	{-68,-25,46,"SafariKick"},
	{-98,-25,47,"ElecSnareDrum"},
    {-128,-25,48,"Snare"},
	{-66,-55,49,"Snap"},
	{-96,-55,50,"Clap"},
	{-126,-55,51,"OpenHat"}
}

dj_uiParams.sSI = {
	{-90,-140},
    {10,-140},
	{-108,-110},
	{10,-110},
    {-35,-40,true},
	{-35,-20,true},
	{-35,0,true}
}

dj_uiParams.switchLight = {
	[1] = {-240,-155,22,26,"a","L","None",-236,-125},
    [2] = {-220,-155,22,26,"b","L","disco",-216,-125},
	[3] = {-200,-155,22,26,"c","L","jazz",-196,-125},
	[4] = {178,-155,22,26,"d","R","electronic1",184,-125},
	[5] = {198,-155,22,26,"e","R","electronic2",204,-125},
	[6] = {218,-155,22,26,"f","R","electronic3",224,-125}
}

function DJSoundboardOverlay:initialise()
	ISPanel.initialise(self);
	local halfW, halfH = self:getWidth()/2, self:getHeight()/2
	LS_DJBooth.speed = LS_DJBooth.speed or 0

	if not dj_cache then
		dj_cache = {}
		dj_cache.overlay = getTexture("media/textures/DJBooth_Overlay.png")
		
		dj_cache.sSI = {}
		dj_cache.sSI.off = getTexture("media/textures/DJBooth_OverlaySwitchIndicatorSmallOff.png")
		dj_cache.sSI.on = getTexture("media/textures/DJBooth_OverlaySwitchIndicatorSmallOn.png")
		dj_cache.sSI.red = getTexture("media/textures/DJBooth_OverlaySwitchIndicatorSmallRED.png")
		
		dj_cache.speed = {}
		dj_cache.speed.red = getTexture("media/textures/DJBooth_OverlayNumber0.png")
		for n=1,4 do
			local strNum = tostring(n)
			dj_cache.speed["n"..strNum] = getTexture("media/textures/DJBooth_OverlayNumber"..strNum..".png")
		end
		dj_cache.speed["n0"] = dj_cache.speed.red
		dj_cache.speed.off = dj_cache.speed["n"..tostring(LS_DJBooth.speed)]
		
		dj_cache.vynil = {}
		dj_cache.vynil.a1 = getTexture("media/textures/DJBooth_VynilA1.png")
		dj_cache.vynil.a2 = getTexture("media/textures/DJBooth_VynilA2.png")
		dj_cache.vynil.b1 = getTexture("media/textures/DJBooth_VynilB1.png")
		dj_cache.vynil.b2 = getTexture("media/textures/DJBooth_VynilB2.png")

		dj_cache.switch = {}
		dj_cache.switch.a = {}
		dj_cache.switch.b = {}
		dj_cache.switch.a.off = getTexture("media/textures/DJBooth_SwitchAOff.png")
		dj_cache.switch.a.on = getTexture("media/textures/DJBooth_SwitchAOn.png")
		dj_cache.switch.b.off = getTexture("media/textures/DJBooth_SwitchBOff.png")
		dj_cache.switch.b.on = getTexture("media/textures/DJBooth_SwitchBOn.png")

		dj_cache.switchLightTex = {}
		dj_cache.switchLightTex.onL = getTexture("media/textures/DJBooth_SwitchCOn.png")
		dj_cache.switchLightTex.offL = getTexture("media/textures/DJBooth_SwitchCOff.png")
		dj_cache.switchLightTex.onR = getTexture("media/textures/DJBooth_SwitchDOn.png")
		dj_cache.switchLightTex.offR = getTexture("media/textures/DJBooth_SwitchDOff.png")

		dj_cache.sB = {}
		dj_cache.sB.on = {}
		dj_cache.sB.off = getTexture("media/textures/DJBooth_OverlayButtonSmall.png")

		dj_cache.bB = {}
		dj_cache.bB.on = {}
		dj_cache.bB.off = getTexture("media/textures/DJBooth_OverlayButtonBig.png")
		
		for n=1,6 do
			local str = tostring(n)
			dj_cache.sB.on[n] = getTexture("media/textures/DJBooth_OverlayButtonSmallPressed"..str..".png")
			dj_cache.bB.on[n] = getTexture("media/textures/DJBooth_OverlayButtonBigPressed"..str..".png")
		end
	end

	local switchLightIndicatorTex, switchLightText = dj_cache.sSI.red, " - "..getText("UI_DJBooth_FloorLight_Missing")
	if self.switchLightInteract then switchLightIndicatorTex, switchLightText = dj_cache.sSI.off, " "; end

	self.DJSoundboardOverlayImage = ISImage:new(halfW-430,halfH-160, 100, 25, dj_cache.overlay)
	self.DJSoundboardOverlayImage:initialise()
	self:addChild(self.DJSoundboardOverlayImage)

------- SPEED/MODE INDICATOR

	self.images.speedImg = ISImage:new(halfW-16,halfH-36, 31, 50, dj_cache.speed.off)
	self.images.speedImg.texKey = "speed"
	local currentSpeed = LS_DJBooth.speed
	self.images.speedImg.currentSpeed = currentSpeed
	self.images.speedImg:initialise()
	self:addChild(self.images.speedImg)

------- REGULAR BUTTONS

	self.buttons.arrows = {}
	for n=1,4 do
		local params = dj_uiParams.arrows[n]
		self.buttons.arrows[n] = ISButton:new(halfW+params[1],halfH+params[2],params[3],params[4],params[5], self, self.onClick)
		self.buttons.arrows[n].internal = params[6]
		self.buttons.arrows[n]:initialise()
		self.buttons.arrows[n]:instantiate()
		self.buttons.arrows[n].borderColor = {r=1, g=1, b=1, a=0.1}
		self:addChild(self.buttons.arrows[n])
	end

------ VYNILS

	local vynilText = getText("UI_DJBooth_Scratch")
	self.buttons.vynils = {}
	for n=1,2 do
		local params = dj_uiParams.vynils[n]
		self.buttons.vynils[n] = ISImage:new(halfW+params[1],halfH+params[2],params[3],params[4],dj_cache.vynil[params[5].."1"])
		self.buttons.vynils[n].internal = params[5]
		self.buttons.vynils[n].phase = "1"
		self.buttons.vynils[n].onMouseUp = self.onMouseUpVynil
		self.buttons.vynils[n]:setMouseOverText(vynilText)
		self.buttons.vynils[n]:initialise()
		self:addChild(self.buttons.vynils[n])
	end

------ SWITCHES

	self.buttons.switch = {}
	for n=1,5 do
		local params = dj_uiParams.switch[n]
		self.buttons.switch[n] = ISImage:new(halfW+params[1],halfH+params[2],params[3],params[4],dj_cache.switch[params[5]].off)
		self.buttons.switch[n].internal = params[5]
		self.buttons.switch[n].lvl = params[6]
		self.buttons.switch[n].idx = n
		self.buttons.switch[n].onMouseUp = (params[7] and self.onMouseUpRecorder) or self.onMouseUpSwitch
		self.buttons.switch[n]:setMouseOverText((self.musicLevel < params[6] and getText("UI_DJBooth_Need",params[6])) or (params[7] and getText(params[7])) or getText("UI_DJBooth_LoopMode"..tostring(n)))
		self.buttons.switch[n]:initialise()
		self:addChild(self.buttons.switch[n])
	end

	-- disco floor switches
	local sLTxt = getText("UI_DJBooth_FloorLight")
	local sLKeys = {"a","b","c","d","e","f"}
	for n=1,#sLKeys do
		local tKey = sLKeys[n]
		local params = dj_uiParams.switchLight[n]
		self.switchLight[tKey] = ISImage:new(halfW+params[1],halfH+params[2],params[3],params[4],dj_cache.switchLightTex["off"..params[6]])
		self.switchLight[tKey].onMouseUp = self.onMouseUpSwitchLight
		self.switchLight[tKey].style = params[7]
		self.switchLight[tKey].key = params[5]
		self.switchLight[tKey].texPos = params[6]
		self.switchLight[tKey]:setMouseOverText(sLTxt.." "..tostring(n)..switchLightText)
		self.switchLight[tKey]:initialise()
		self:addChild(self.switchLight[tKey])
		self.switchLight[tKey].light = ISImage:new(halfW+params[8],halfH+params[9],12,13,switchLightIndicatorTex)
		self.switchLight[tKey].light:initialise()
		self:addChild(self.switchLight[tKey].light)
	end


------ SMALL BUTTONS

	-- small switch indicator
	for n=1,#dj_uiParams.sSI do
		local params = dj_uiParams.sSI[n]
		local idx = "sSI"..tostring(n)
		self.images[idx] = ISImage:new(halfW+params[1],halfH+params[2], 12, 13, dj_cache.sSI.off)
		self.images[idx].texKey = "sSI"
		self.images[idx].failOff = params[3]
		self.images[idx]:initialise()
		self:addChild(self.images[idx])
	end

	-- small buttons (stop loop and switch loops)
	self.buttons.sB = {}
	for n=1,#dj_uiParams.sB do
		local params = dj_uiParams.sB[n]
		self.buttons.sB[n] = ISImage:new(halfW+params[1],halfH+params[2],params[3],params[4],dj_cache.sB.off)
		self.buttons.sB[n].rgb = 1
		self.buttons.sB[n].internal = n
		self.buttons.sB[n].switch = params[5]
		self.buttons.sB[n].kP = params[7]
		self.buttons.sB[n].onMouseUp = (not params[7] and self.onMouseUpStartLoop) or (not params[5] and self.onMouseUpStopLoop) or self.onMouseUpSmallButton
		self.buttons.sB[n]:setMouseOverText((params[5] and getText("UI_DJBooth_Loop"..tostring(params[5])..params[6])) or getText(params[6]))
		self.buttons.sB[n]:initialise()
		self:addChild(self.buttons.sB[n])
	end

------ BIG BUTTONS

	self.buttons.bBR = {}
	for n=1,#dj_uiParams.bBR do
		local params = dj_uiParams.bBR[n]
		self.buttons.bBR[n] = ISImage:new(halfW+params[1],halfH+params[2],25,25,dj_cache.bB.off)
		self.buttons.bBR[n].rgb = 1
		self.buttons.bBR[n].count = 0
		self.buttons.bBR[n].total = params[3]
		self.buttons.bBR[n].kP = params[4]
		self.buttons.bBR[n].onMouseUp = self.onMouseUpBigButtonRight
		self.buttons.bBR[n]:setMouseOverText(getText("UI_DJBooth_"..params[5]))
		self.buttons.bBR[n]:initialise()
		self:addChild(self.buttons.bBR[n])
	end

	self.buttons.bBL = {}
	for n=1,#dj_uiParams.bBL do
		local params = dj_uiParams.bBL[n]
		self.buttons.bBL[n] = ISImage:new(halfW+params[1],halfH+params[2],25,25,dj_cache.bB.off)
		self.buttons.bBL[n].rgb = 1
		self.buttons.bBL[n].count = 0
		self.buttons.bBL[n].total = 1
		self.buttons.bBL[n].kP = params[3]
		self.buttons.bBL[n].idx = n
		self.buttons.bBL[n].onMouseUp = self.onMouseUpBigButtonLeft
		self.buttons.bBL[n].onRightMouseUp = self.onMouseUpRecorder
		self.buttons.bBL[n]:setMouseOverText(getText("UI_DJBooth_"..params[4]))
		self.buttons.bBL[n]:initialise()
		self:addChild(self.buttons.bBL[n])
	end

    --
    self.ok = ISButton:new((self:getWidth() / 2) - 19, self:getHeight() - 34, 30, 30, getText("UI_DJBooth_Close"), self, self.onClick);
    self.ok.internal = "Close";
    self.ok:initialise();
    self.ok:instantiate();
    self.ok.borderColor = {r=1, g=1, b=1, a=0.1};
    self:addChild(self.ok);

    --self:insertNewLineOfButtons(self.button1p, self.button2p, self.button3p, self.button4p)
    self:insertNewLineOfButtons(self.ok)

end

function DJSoundboardOverlay:update()
	if self.switchLightDelay > 0 then
		self.switchLightDelay = self.switchLightDelay-1
		if self.switchLightDelay <= 0 then
			resetSwitchLightIndicatorTex(self)
		end
	end

	if not LS_DJBooth.failstate then
		if self.loop then
			local idx, count
			for n=1,3 do
				if self["loopActive"] == n then
					local str = tostring(n)
					self["loopCount"..str] = self["loopCount"..str]+1
					count = self["loopCount"..str]
					idx = str
					if not self.buttons.switch[5].active or (count and count >= self["loopCount"..str.."Limit"]) then
						self.loop = false
						self["loopCount"..str.."Total"] = count
						self["loopCount"..str] = math.floor((1000*n)-1000)
						if self.buttons.switch[5].active then
							self.buttons.switch[5].active = false
							self.buttons.switch[5].texture = dj_cache.switch.b.off
						end
					end
					break
				end
			end
			if count and self.loopKey ~= 0 then
				self.loopTable[count] = self.loopKey
				self.loopKey = 0
			end
		end
		if self.loopPlaying and ((self.loopActive == 1 and not self.loop) or self.loopActive > 1) then
			for n=1,3 do
				local str = tostring(n)
				if n <= self.loopActive and (not self.loop or self.loopActive ~= n) then
					local count = self["loopCount"..str]
					if count > self["loopCount"..str.."Limit"] or count > self["loopCount"..str.."Total"] then
						count = math.floor((1000*n)-1000)
					end
					self["loopCount"..str] = count+1
				end
				local key = self["loopCount"..str]
				if key > 0 and self.loopTable[key] then
					local keyPress = self.loopTable[key]
					self:onRecordedLoop(keyPress)
				end
			end
			
		end
		--self.up_count = self.up_count + 1
		self.bBR_count = self.bBR_count+1
		--if self.up_count % self.up_delay ~= 0 then return; end
		--self.up_count = 0
	else
		self.loop = false
		self.loopActive = 0
		self.loopPlaying = false
		self.buttons.sB[17].active = false
		if self.buttons.switch[5].active then
			self.buttons.switch[5].active = false
			self.buttons.switch[5].texture = dj_cache.switch.b.off
		end
	end

	if LS_DJBooth.failstate then self.images.speedImg.currentSpeed = 0; end
	if LS_DJBooth.speed ~= self.images.speedImg.currentSpeed then
		if not LS_DJBooth.failstate then
			local currentSpeed = LS_DJBooth.speed
			dj_cache.speed.off = dj_cache.speed["n"..tostring(currentSpeed)]
			self.images.speedImg.currentSpeed = currentSpeed
		end
		local targetTex = (LS_DJBooth.failstate and dj_cache.speed.red) or dj_cache.speed.off
		if self.images.speedImg.texture ~= targetTex then self.images.speedImg.texture = targetTex; end
	end
	for k, v in pairs(self.images) do
		if v.active and v.failOff and LS_DJBooth.failstate then v.active = false; end
		local targetTex = (LS_DJBooth.failstate and dj_cache[v.texKey].red) or (v.active and dj_cache[v.texKey].on) or dj_cache[v.texKey].off
		if v.texture ~= targetTex then v.texture = targetTex; end
	end

	for n=1,#self.buttons.switch do
		local swt = self.buttons.switch[n]
		local targetTex = (swt.active and dj_cache.switch[swt.internal].on) or dj_cache.switch[swt.internal].off
		if swt.texture ~= targetTex then swt.texture = targetTex; end
		LS_DJBooth.buttons.switch[swt.idx] = swt.active
	end

	for n=1,#self.buttons.sB do
		local sBtn = self.buttons.sB[n]
		local isActive = sBtn.active and not LS_DJBooth.failstate and (not sBtn.switch or self.buttons.switch[sBtn.switch].active)
		local targetTex = (isActive and dj_cache.sB.on[sBtn.rgb]) or dj_cache.sB.off
		if sBtn.texture ~= targetTex then sBtn.texture = targetTex; end
		if sBtn.active ~= isActive then sBtn.active = isActive; end
	end

	local bBtime
	if self.bBR_count % self.bBR_delay == 0 then
		self.bBR_count = 0
		bBtime = true
	end
	for n=1,#self.buttons.bBR do
		doBigButtonLogic(self.buttons.bBR[n], bBtime)
	end
	for n=1,#self.buttons.bBL do
		doBigButtonLogic(self.buttons.bBL[n], bBtime)
	end

    ISPanelJoypad.update(self)  
end

function DJSoundboardOverlay:updateStatus(btn)
	if btn then
		self.btnRGB = self.btnRGB+1
		if self.btnRGB > 6 then self.btnRGB = 1; end
		btn.rgb = self.btnRGB
	end

	if self.loopPlaying then self.buttons.sB[17].active = true; end

end

function DJSoundboardOverlay:close()
	LS_DJBooth.buttons.switch = {}
	LS_DJBooth.speed = 0
	
	self:setVisible(false);
	self:removeFromUIManager();
	if UIManager.getSpeedControls() then
		UIManager.getSpeedControls():SetCurrentGameSpeed(1);
	end
end

function DJSoundboardOverlay:destroy()
	LS_DJBooth.buttons.switch = {}
	LS_DJBooth.speed = 0

	self:setVisible(false);
	self:removeFromUIManager();
	if UIManager.getSpeedControls() then
		UIManager.getSpeedControls():SetCurrentGameSpeed(1);
	end
end

function DJSoundboardOverlay:onClick(button)

    if button.internal == "Close" then
        self:destroy();
        if JoypadState.players[self.playerNum+1] then
            setJoypadFocus(self.playerNum, nil)
        end
	else

    end
	if not LS_DJBooth.failstate then
		if button.internal == "RIGHTLEFT" then	
			LS_DJBooth.keyLEFTRIGHT = true
		elseif button.internal == "UP" then	
			if LS_DJBooth.speed == 4 or (LS_DJBooth.speed >= 1 and self.musicLevel >= 6) or (LS_DJBooth.speed == 1 and self.musicLevel >= 3) then
				LS_DJBooth.keyUP = true
			else
			LS_DJBooth.keyLEFTRIGHT = true
			end
		elseif button.internal == "DOWN" then	
			LS_DJBooth.keyDOWN = true
		end
	end
end

function DJSoundboardOverlay:prerender()
	self:drawRect(0, 0, self.width, self.height, self.backgroundColor.a, self.backgroundColor.r, self.backgroundColor.g, self.backgroundColor.b);
	self:drawRectBorder(0, 0, self.width, self.height, self.borderColor.a, self.borderColor.r, self.borderColor.g, self.borderColor.b);

end

function DJSoundboardOverlay:render()

end

function DJSoundboardOverlay:onGainJoypadFocus(joypadData)
	ISPanelJoypad.onGainJoypadFocus(self, joypadData)
	self.joypadIndexY = 1
	self.joypadIndex = 1
	self.joypadButtons = self.joypadButtonsY[self.joypadIndexY]
	self.joypadButtons[self.joypadIndex]:setJoypadFocused(true)
end

function DJSoundboardOverlay:onJoypadDown(button)
	ISPanelJoypad.onJoypadDown(self, button)
	if button == Joypad.BButton then
		self:onClick(self.ok)
	end
end

local function getDFMLight(object)
	local hasDF
	for x = object:getX()-8,object:getX()+8 do
		for y = object:getY()-8,object:getY()+8 do
			local square = getCell():getGridSquare(x,y,object:getZ());
			if square then
				for i = 0,square:getObjects():size()-1 do
					local newObject = square:getObjects():get(i);
					if newObject and instanceof(newObject, "IsoObject") then
						if getCustomName(newObject, "Disco Floor") and newObject:getModData().IsMainDF then
							hasDF = true
							break
						end
					end
				end
			end
			if hasDF then break; end
		end
		if hasDF then break; end
	end
	return hasDF
end

function DJSoundboardOverlay:new(character, DJbooth)
	local x = 0
	local y = 0
	local width = 860
	local height = 320
	local o = ISPanelJoypad:new(x, y, width, height);
	setmetatable(o, self)
    self.__index = self
	o.character = character
	o.playerNum = o.character:getPlayerNum()
	o.musicLevel = o.character:getPerkLevel(Perks.Music)
	o.name = nil;
    o.backgroundColor = {r=0, g=0, b=0, a=0.1};
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
    if y == 0 then
		o.y = getPlayerScreenTop(o.playerNum) + (getPlayerScreenHeight(o.playerNum) - height) / 2 + 420
        o:setY(o.y)
    end
    if x == 0 then
		o.x = getPlayerScreenLeft(o.playerNum) + (getPlayerScreenWidth(o.playerNum) - width) / 2
        o:setX(o.x)
    end
	o.width = width;
	o.height = height;
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	--o.target = target;
	--o.onclick = onclick;
	o.djbooth = DJbooth
	o.djbooth:getModData().LightStyle = "None"
	--o.djbooth:transmitModData()
	sendClientCommand("LS", "ModifyObjData", {{o.djbooth:getX(),o.djbooth:getY(),o.djbooth:getZ(),o.djbooth:getSprite():getName()}, false, o.djbooth:getModData()})
    --o.playerX = getPlayer():getX()
    --o.playerY = getPlayer():getY()
	--o.DJSoundboardTexture = getTexture("DJBooth_Overlay0.png")
	o.switchLight = {a=false,b=false,c=false,d=false,e=false,f=false}
	o.switchLightDelay = 0
	o.switchLightInteract = false
	if getDFMLight(o.djbooth) then o.switchLightInteract = true; end
	o:noBackground()
	o.buttons = {}
	o.images = {}
	o.loopActive = 0
	o.loopKey = 0
	o.loopTable = {}
	o.bBR_count = 0
	o.bBR_delay = 10
	local count = 0
	for n=1,3 do
		local str = tostring(n)
		o["loopCount"..str] = count
		o["loopCount"..str.."Total"] = count
		o["loopCount"..str.."Limit"] = count+999
		count = count+1000
	end
	o.btnRGB = 0
    return o;
end
