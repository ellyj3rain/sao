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

require "TimedActions/ISBaseTimedAction"

LSIWAction = ISBaseTimedAction:derive("LSIWAction");

function LSIWAction:isValid()
	return true;
end

function LSIWAction:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.obj)
	return self.character:shouldBeTurning()
end

local function stopSound(character, sound)
	if sound and sound ~= 0 and character:getEmitter():isPlaying(sound) then
		character:stopOrTriggerSound(sound)
	end
end

local function getNewSound(oldSound, soundName, soundVar)
	if soundName and not soundVar then return soundName; end
	if not soundName and not soundVar then return "PutItemInBag"; end
	if type(soundVar) == "number" then return soundName..tostring(ZombRand(soundVar)+1); end
	return LSUtil.getNewParam(oldSound, soundVar)
end

local function getPhaseProgress(totalDuration, currentProgress, returnStr)
	local val = 0

	if currentProgress and currentProgress <= 0 then
		val = 99
	elseif totalDuration then
		local realProgress = totalDuration - currentProgress
		if realProgress > 0 then val = LSUtil.getPercentage(totalDuration,realProgress); end
	end
	if not returnStr then return math.min(99,val); end
	
	local valStr = tostring(math.floor(math.min(99,val)))
	if val > 9 then
		local digit1 = string.sub(valStr, 1, 1)
		local digit2 = string.sub(valStr, 2, 2)
		return digit1, digit2
	end
	return valStr, false
end

function LSIWAction:update()
	if self.character:isSitOnGround() or self.character:getVehicle() then self:forceStop(); end

	self.deltaAdd = getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck
	self.fakeDelta = self.fakeDelta+self.deltaAdd
	self.jobProgress = self.fakeDelta
	self.jobTotal = self.jobTotal+self.deltaAdd
	if self.jobTotal > 450 then
		self.jobTotal = 0
		self.rollDelay = false
		self['cogEffect'](self)
		self['rollChance'](self)
	elseif not self.rollDelay and self.jobTotal > 225 then
		self.rollDelay = true
		self['rollChance'](self)
	end

	for _, phase in ipairs(self.phases) do
		if (not self.phaseStates[phase.name]) and self.jobProgress > (self.fakeMax * phase.threshold) then
			self.phaseStates[phase.name] = true
			self[phase.handler](self)
			break
		--elseif self.phaseStates[phase.name] and self.jobProgress < (self.maxTime * phase.threshold) then
			--self.phaseStates[phase.name] = false
		end
	end

	--local timeTick = getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck -- do not use it here

	
	if self.animVars.countTotal then
		if not self.animVars.count then self.animVars.count = 0; end
		self.animVars.count = self.animVars.count+(getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		if self.animVars.count >= self.animVars.countTotal then
			self.animVars.count = 0
			if not self.animVars.start then
				self.animVars.start = true
				self.animVars.countTotal = self.animVars.soundTime
			end
			stopSound(self.character, self.sound)
			self.soundName = getNewSound(self.soundName, self.animVars.soundName, self.animVars.soundVar)
			self.sound = self.character:playSound(self.soundName)
					--stopSound(self.character, self.sound)
					--self.soundName = LSUtil.getNewParam(self.soundName, self.soundTable[self.soundGroup])
					--self.sound = self.character:playSound(self.soundName)

				--if self.sandboxFailChance and self.animVars.fail > 0 and not self.doFailState then
				--	if ZombRand(100)+1+10*self.skillLevel <= math.min(80, (self.animVars.fail + self.baseFailChance)*self.sandboxFailChance) then self.doFailState = true; end
				--	self.animVars.fail = 0
				--end
				--if self.animVars.playOnce then self.animVars.countTotal = false; end
		end
	end

	self.character:setMetabolicTarget(Metabolics[self.exerciseMetabolics])
end
--[[
function LSIWAction:cacheSprites()
	for n=1,#self.splashTable do
		spriteName = self.splashTable[n]
		local sprite = IsoSprite.new()
		sprite:LoadSingleTexture(spriteName)
		self.spriteCache[spriteName] = sprite
	end
end
]]--

function LSIWAction:explosionEffect()
	if self.isSchematics then return; end
	local splashColor = {r=1, g=1, b=1, a=1}
	local texture = getTexture("media/textures/Smoke_Black_A.png")
	-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
	-- animate, {text=textColor, tex=texColor}, {coordX, coordY, coordZ, offsetX, offsetY}, {scaleW, scaleH}
	local mainArgs = {false,false,texture,false,0.02,false,-1.5,3,3,false,false}
	local coords = {self.objX, self.objY, self.objZ, -20, -20}
	local explosionOverlay = LSTAOverlay:new(self.character, mainArgs, false, {tex=splashColor},coords,{48,48}) -- {64*Core.getTileScale(),128*Core.getTileScale()}
	explosionOverlay:initialise()
	explosionOverlay:addToUIManager()
	LSUtil.makeCharExplode(self.character, {{4,6,10},2,3,{"Torso_Upper","Torso_Lower","ForeArm_L","ForeArm_R","UpperArm_L","UpperArm_R","Hand_L","Hand_R"}})
	LSUtil.playSoundCharacter(self.character, "InvWorkbench_Explosion", false, false, true, false, {0.6,false}, false)
end

function LSIWAction:papersEffect()
	local paperColor = {r=1, g=1, b=1, a=1}
	local paperNums = {LSUtil.rdm_inst:random(10), LSUtil.rdm_inst:random(10)}
	if paperNums[2] == paperNums[1] then paperNums[2] = (paperNums[1] > 8 and 1) or paperNums[1]+2; end
	local facing = (self.spriteName == "LS_Inventions_10" and "E") or "S"
	local colors = {"white","white","white","lightBlue","lightBlue","lightGreen","lightGreen","lightOrange","lightPink","lightRed","lightYellow"}
	local addDelay
	for n=1,2 do
		local rdmSprite = "media/textures/papers/Paper_"..tostring(paperNums[n])..".png"
		local rdmColor = LSUtil.rdm_inst:random(#colors)
		local texture = getTexture(rdmSprite)
		local offset = LSUtil.rdm_inst:random(10)
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		if LSUtil.rdm_inst:random(2) == 1 then offset = -offset; end
		local moveY = -(LSUtil.rdm_inst:random(10)*0.2)
		local moveX = LSUtil.rdm_inst:random(10)*0.2
		if facing == "E" then moveX = -moveX; end
		local posX, posY = -5,0
		if facing == "S" then posX, posY = -40,-5; end
		local mainArgs = {false, false, texture, false, 0.05, moveX, moveY, false,false,false,true}
		local coords = {self.objX, self.objY, self.objZ, posX+offset, posY-offset}
		local overlay = LSTAOverlay:new(self.character, mainArgs,{delay=addDelay,closeAfter=true,rate=10,tex={rdmSprite}}, {pickTex=colors[rdmColor]},coords,{30,23}) -- {64*Core.getTileScale(),128*Core.getTileScale()}
		overlay:initialise()
		overlay:addToUIManager()
		local newDelay = LSUtil.rdm_inst:random(6,20)
		addDelay = (addDelay and addDelay+newDelay) or newDelay
	end

	if not self.phaseStates["d"] and not self.bubbleSound and LSUtil.rdm_inst:random(10) == 1 then
		self.bubbleSound = true
		LSUtil.playSoundCharacter(self.character, "Water_Bubbling", false, false, true)
	end
end

function LSIWAction:splashEffect()
	if self.isSchematics then self['papersEffect'](self); return; end
	local splashColor = {r=1, g=1, b=1, a=1}
	self.splashSprite = LSUtil.getNewParam(self.splashSprite, self.splashTable)
	local texture = getTexture("media/textures/"..self.splashSprite..".png")
	--texture:splitIcon()
	if not self.splashOverlay then
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		-- animate, {text=textColor, tex=texColor}, {coordX, coordY, coordZ, offsetX, offsetY}, {scaleW, scaleH}
		local mainArgs = {false,false,texture,false,0.02,false,-1,2,2,false,true}
		local coords = {self.objX, self.objY, self.objZ, -20, -20}
		self.splashOverlay = LSTAOverlay:new(self.character, mainArgs, false, {tex=splashColor},coords,{32,32}) -- {64*Core.getTileScale(),128*Core.getTileScale()}
		self.splashOverlay:initialise()
		self.splashOverlay:addToUIManager()
	else
		local rdmX = LSUtil.rdm_inst:random(40)
		if LSUtil.rdm_inst:random(2) == 1 then rdmX=-rdmX; end
		local rdmY = LSUtil.rdm_inst:random(40)
		if LSUtil.rdm_inst:random(2) == 1 then rdmY=-rdmY; end
		self.splashOverlay.ogX = rdmX-20
		self.splashOverlay.ogY = rdmY-20
		self.splashOverlay:resetOverlay(texture)
		self.splashOverlay.color.tex = splashColor
	end
	
	self.splashSoundName = LSUtil.getNewParam(self.splashSoundName, self.splashSounds)
	LSUtil.playSoundCharacter(self.character, self.splashSoundName, false, false, true, false, {0.3,false}, false)
end

function LSIWAction:cogEffect()
	local texture = getTexture("media/textures/InvCog_A.png")
	--texture:splitIcon()
	if not self.cogOverlay then
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		local mainArgs = {false, false, texture, false, 0.01,false,false,false,false,true,true}
		local coords = {self.character:getX(), self.character:getY(), self.character:getZ(), -20, -140}
		self.cogOverlay = LSTAOverlay:new(self.character, mainArgs,{loop=true,rate=10,tex={"media/textures/InvCog_A.png","media/textures/InvCog_B.png"}},false,coords,{32,32}) -- {64*Core.getTileScale(),128*Core.getTileScale()}
		self.cogOverlay:initialise()
		self.cogOverlay:addToUIManager()
	else
		self.cogOverlay:resetOverlay(texture)
	end

	--if self.workParams[2] == "Invention" then return; end

	local digit1, digit2 = getPhaseProgress(self.objData.duration, self.duration-self.jobProgress, true)

	local digit1_texture = getTexture("media/textures/text/sims/Num_"..digit1..".png")
	--texture:splitIcon()
	if not self.digit1_overlay then
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		local mainArgs = {false, false, digit1_texture, false, 0.01,false,false,false,false,true,true}
		local coords = {self.character:getX(), self.character:getY(), self.character:getZ(), 0, -140}
		self.digit1_overlay = LSTAOverlay:new(self.character, mainArgs,false,false,coords,{12,16})
		self.digit1_overlay:initialise()
		self.digit1_overlay:addToUIManager()
	else
		self.digit1_overlay:resetOverlay(digit1_texture)
	end

	local percent_texture = getTexture("media/textures/text/sims/SC_Percent.png")
	if not self.percent_overlay then
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		local mainArgs = {false, false, percent_texture, false, 0.01,false,false,false,false,true,true}
		local coordX = (digit2 and 24) or 12
		local coords = {self.character:getX(), self.character:getY(), self.character:getZ(), coordX, -140}
		self.percent_overlay = LSTAOverlay:new(self.character, mainArgs,false,false,coords,{12,16})
		self.percent_overlay:initialise()
		self.percent_overlay:addToUIManager()
	else
		local coordX = (digit2 and 24) or 12
		if self.percent_overlay:getX() ~= coordX then self.percent_overlay:setX(coordX); end
		self.percent_overlay:resetOverlay(percent_texture)
	end

	if not digit2 then return; end
	local digit2_texture = getTexture("media/textures/text/sims/Num_"..digit2..".png")
	if not self.digit2_overlay then
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		local mainArgs = {false, false, digit2_texture, false, 0.01,false,false,false,false,true,true}
		local coords = {self.character:getX(), self.character:getY(), self.character:getZ(), 12, -140}
		self.digit2_overlay = LSTAOverlay:new(self.character, mainArgs,false,false,coords,{12,16})
		self.digit2_overlay:initialise()
		self.digit2_overlay:addToUIManager()
	else
		self.digit2_overlay:resetOverlay(digit2_texture)
	end
end

function LSIWAction:gnomeStarsEffect()
	if not self.gnomeSpawn then return; end
	local colors = {"orange","yellow","darkYellow","pink"}
	local textureVar = {"A","B","C"}
	local addDelay
	for n=1,8 do
		local rdmColor = LSUtil.rdm_inst:random(#colors)
		local rdmFW, rdmBlast = LSUtil.rdm_inst:random(#textureVar), LSUtil.rdm_inst:random(#textureVar)
		local texture = getTexture("media/textures/fireworks/SmallFW_"..textureVar[rdmFW]..".png")
		local offsetX, offsetY, size = LSUtil.rdm_inst:random(40), LSUtil.rdm_inst:random(40), LSUtil.rdm_inst:random(15)/10
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		if LSUtil.rdm_inst:random(2) == 1 then offsetX = -offsetX; end
		if LSUtil.rdm_inst:random(2) == 1 then offsetY = -offsetY; end
		local mainArgs = {false, false, texture, false, 0.02/size, false, false,1+size,1+size,true,false}
		local coords = {self.objX, self.objY, self.objZ, -20+offsetX, -30+offsetY}
		local overlay = LSTAOverlay:new(self.character, mainArgs,{delay=addDelay,closeAfter=true,rate=10,tex={"media/textures/fireworks/SmallFW_"..textureVar[rdmFW]..".png",}}, {pickTex=colors[rdmColor]},coords,{8,8}) -- {64*Core.getTileScale(),128*Core.getTileScale()}
		overlay:initialise()
		overlay:addToUIManager()
		addDelay = (addDelay and addDelay+2) or 2
	end
end


function LSIWAction:fireworksEffect()
	if self.gnomeSpawn then self['gnomeStarsEffect'](self); return; end
	local colors = {"orange","yellow","darkYellow","pink"}
	local textureVar = {"A","B","C"}
	local addDelay
	for n=1,4 do
		local rdmColor = LSUtil.rdm_inst:random(#colors)
		local rdmFW, rdmBlast = LSUtil.rdm_inst:random(#textureVar), LSUtil.rdm_inst:random(#textureVar)
		local texture = getTexture("media/textures/fireworks/SmallFW_"..textureVar[rdmFW]..".png")
		local offsetX, offsetY, power, size = LSUtil.rdm_inst:random(20), LSUtil.rdm_inst:random(10), LSUtil.rdm_inst:random(20)/10, LSUtil.rdm_inst:random(15)/10
		local blastTime = LSUtil.rdm_inst:random(10,20)
		-- mainArgs {font, text, texture, isTile, fadeTime, moveX, moveY, resizeX, resizeY, ignoreDL, isTA}
		local moveX = 0.5+power/2
		if LSUtil.rdm_inst:random(2) == 1 then moveX = -moveX; end
		if LSUtil.rdm_inst:random(2) == 1 then offsetX = -offsetX; end
		if LSUtil.rdm_inst:random(2) == 1 then offsetY = -offsetY; end
		local mainArgs = {false, false, texture, false, 0.01/size, moveX,-1-power,1+size,1+size,true,false}
		local coords = {self.objX, self.objY, self.objZ, -20+offsetX, -20+offsetY}
		local overlay = LSTAOverlay:new(self.character, mainArgs,{delay=addDelay,closeAfter=true,rate=10,tex={"media/textures/fireworks/SmallFW_"..textureVar[rdmFW]..".png","media/textures/fireworks/SmallFW_Blast_"..textureVar[rdmBlast]..".png"}}, {pickTex=colors[rdmColor]},coords,{8,8}) -- {64*Core.getTileScale(),128*Core.getTileScale()}
		overlay:initialise()
		overlay:addToUIManager()
		addDelay = (addDelay and addDelay+6) or 6
	end
	LSUtil.playSoundCharacter(self.character, "Fireworks_SETOFF_SHORT", false, false, true, false, {0.6,false}, false)
end

function LSIWAction:removeSplashObj()
	if self.splashOverlay then self.splashOverlay:close(); end
	if self.cogOverlay then self.cogOverlay:close(); end
	if self.digit1_overlay then self.digit1_overlay:close(); end
	if self.digit2_overlay then self.digit2_overlay:close(); end
	if self.percent_overlay then self.percent_overlay:close(); end
end

function LSIWAction:grantXP(performBonus)
	local skillLevel = math.max(1, HiddenSkills.getLevel(self.character, "Inventing"))
	if skillLevel >= 10 then return; end
	local trait = (CharacterTrait.INVENTIVE and self.character:hasTrait(CharacterTrait.INVENTIVE) and 1.5) or 1
	local bonus = performBonus or 0
	local div = ((self.isSchematics or self.workParams[2] == "Production") and 2) or 1
	
	local xp = (1*skillLevel)+self.objData.level
	xp = (xp*self.skillBoost*trait)+bonus
	xp = xp/div
	
	HiddenSkills.addXP(self.character, "Inventing", math.ceil(xp))
	
end

local function getFailType(crit)
	local chanceTable = {}
	local failTypes = (crit and
		{
			["Ruined"]=1,
			["Reset"]=4,
			["Explosion"]=2,
			["Void"]=6,
		}) or
		{
			["Study"]=16,
			["Material"]=4,
			["Skill"]=4,
			["Progress"]=8,
		}
	for k, v in pairs(failTypes) do
		if v and v > 0 then
			for n=1,v do
				table.insert(chanceTable, k)
			end
		end
	end
	local rdmType = LSUtil.rdm_inst:random(#chanceTable)
	return chanceTable[rdmType]
end

function LSIWAction:failSmall() -- name, newDuration, mentalBlock, bummed, readd costs, crit
	local failType = getFailType(nil)
	if failType == "Skill" then 
		local skillLevel = HiddenSkills.getLevel(self.character, "Inventing")
		if skillLevel < 2 or skillLevel == 10 then
			failType = "Study"
		else
			local skillReduction = skillLevel*150
			HiddenSkills.removeXP(self.character, "Inventing", LSUtil.rdm_inst:random(math.floor(skillReduction/2),skillReduction))
		end
	end
	if failType == "Material" and not self.obj:getModData()['costFail'] then failType = "Study"; end
	local bummedChance = LSUtil.rdm_inst:random(4)
	local mentalBlock = (failType == "Study" or (failType == "Material" and self.workParams[2] == "Research" and self.workParams[1] == 1)) and LSUtil.rdm_inst:random(2,4)
	local newDuration = failType == "Progress" and math.min(self.objData.duration,math.max(1000,math.ceil(self.duration*1.5)))
	local addCosts = failType == "Material" and not mentalBlock

	self.failArgs = {failType,newDuration,mentalBlock,bummedChance==1 and 0.4,addCosts,nil}
	self:forceStop()
end

function LSIWAction:failBig()
	local failType = getFailType(true)
	if self.isSchematics and failType == "Explosion" then failType = "Void"; end
	local newDuration = (failType == "Reset" and self.objData.duration) or (failType == "Explosion" and math.min(self.objData.duration,math.max(5000,math.ceil(self.duration*4))))
	local mentalBlock = failType == "Void" and LSUtil.rdm_inst:random(12,24)
	local addCosts = failType == "Explosion"
	self.failArgs = {failType,newDuration,mentalBlock,1.0,failType == "Explosion",true}
	self:forceStop()
end

local function getLuckType(crit)
	local chanceTable = {}
	local luckTypes = (crit and
		{
			["FocusGood"]=2, -- can't be triggered if focus was triggered before, all future negative rolls become good
			["ProgressBig"]=4, -- adds big chunk of progress (20-30% of current duration), does not trigger rolls near or covered by new progress
			["SkillBig"]=6, -- adds big chunk of skill (proportional to skill level), can't happen if skill level is max
			["InstaFinish"]=1, -- can only occur at last phase and if roll happens at 50% or higher completion, instantly force completes
		}) or
		{
			["Focus"]=2, -- can't be triggered if focus good was triggered before, no more good or bad rolls can happen (until end of phase)
			["SkillBoost"]=4, -- small boost to skill gain (until end of session), can't happen if skill level is max
			["Progress"]=8, -- adds a small bit of progress (2-5% of current duration)
			["Skill"]=8, -- adds small chunk of skill (proportional to skill level), can't happen if skill level is max
			["GoodMood"]=4, -- resets stress, unhappiness and boredom
			["Lucky"]=4, -- prevents the next bad outcome (in any phase)
		}
	for k, v in pairs(luckTypes) do
		if v and v > 0 then
			for n=1,v do
				table.insert(chanceTable, k)
			end
		end
	end
	local rdmType = LSUtil.rdm_inst:random(#chanceTable)
	return chanceTable[rdmType]
end

local function doNote(character, text, texture, addW)
	 -- Player, Text, Type, Texture, ScreenTime, ClosePermanent, InfoPanel, NoSpam, Texture Properties
	LSNoteMng.addToQueue(getCore():getScreenWidth()-(400+addW),(getCore():getScreenHeight()/5)-50,300+addW,50, {character, text, false, texture, 5, false, false, false, {6,10,30}})
end

function LSIWAction:updateWorkbench() -- name, newDuration, shouldComplete, newResult, crit
	local objData = self.obj:getModData()
	local eventData = objData['events']
	local newDuration = self.duration

	if self.luckArgs then
		eventData['good'] = eventData['good'] or {}
		eventData['good']['num'] = (eventData['good']['num'] and eventData['good']['num']+1) or 1
		eventData['good'][self.luckArgs[1]] = true
		if self.luckArgs[4] then objData.result = self.luckArgs[4][1]; objData.resultType = self.luckArgs[4][2]; end
		if self.luckArgs[3] then -- add text to finished note at perform
			self:forceComplete()
			return
		end

		newDuration = self.luckArgs[2] or newDuration

		local title = "Small"
		if self.luckArgs[5] then -- crit
			title = "Big"
			eventData['crit'] = self.luckArgs[1]
		end
		
		getSoundManager():playUISound("UI_Painting_Complete")
		doNote(self.character, " <RGB:0.7,1,0.7><CENTRE>"..getText("IGUI_InvWorkbench_Luck"..title).." <LINE><TEXT>"..getText("IGUI_InvWorkbench_Luck"..title.."_"..self.luckArgs[1]), "media/ui/lucky_legacy.png", 100)

		if self.luckArgs[1] == "Lucky" then 
			eventData['Lucky'] = true
		elseif self.luckArgs[1] == "ProgressBig" then
			eventData['target'][4] = true
		end
		
		--LSSync.updateClientData(self.character, charData)
	end

	self.duration = newDuration
	objData.progress = newDuration
	if isClient() then sendClientCommand("LS", "ModifyObjData", {{self.obj:getX(),self.obj:getY(),self.obj:getZ(),self.obj:getSprite():getName()}, false, objData}); end
	
	self.luckArgs = false
end

function LSIWAction:luckSmall(FocusGood) -- name, newDuration, shouldComplete, newResult, crit
	local luckType = getLuckType(nil)
	if FocusGood and luckType == "Focus" then luckType = "Progress"; end
	if luckType == "Skill" or luckType == "SkillBoost" then 
		local skillLevel = math.max(1, HiddenSkills.getLevel(self.character, "Inventing"))
		if skillLevel == 10 then
			luckType = "GoodMood"
		elseif luckType == "Skill" then
			local skillIncrease = skillLevel*50
			HiddenSkills.addXP(self.character, "Inventing", LSUtil.rdm_inst:random(math.floor(skillIncrease/2),skillIncrease))
		else
			self.skillBoost = 2
		end
	end
	local newDuration = luckType == "Progress" and math.floor(self.duration*0.9)

	if luckType == "GoodMood" then
		LSUtil.changeCharacterMoodGroup(self.character, {
			["Boredom"] = {0, false, true, true},
			["Unhappiness"] = {0, false, true, true},
			["Stress"] = {0, false, true, true},
			["Thirst"] = {0, false, true, true},
			["Hunger"] = {0, false, true, true},
		})
	end

	self.luckArgs = {luckType,newDuration,nil,nil,nil}
	self['updateWorkbench'](self)
end

function LSIWAction:luckBig() -- name, newDuration, shouldComplete, newResult, crit
	local luckType = getLuckType(true)
	if luckType == "SkillBig" then
		local skillLevel = math.max(1, HiddenSkills.getLevel(self.character, "Inventing"))
		if skillLevel == 10 then
			luckType = "ProgressBig"
		else
			local skillIncrease = skillLevel*200
			HiddenSkills.addXP(self.character, "Inventing", LSUtil.rdm_inst:random(math.floor(skillIncrease/2),skillIncrease))
		end
	end
	local newDuration = luckType == "ProgressBig" and math.floor(self.duration*0.4)

	self.luckArgs = {luckType,newDuration,luckType == "InstaFinish",nil,true}
	self['updateWorkbench'](self)
end

local function getGnomeName()
	local name = getText("IGUI_GnomesName_"..tostring(LSUtil.rdm_inst:random(60)))
	local preffix, suffix = "", ""
	local useSuffix = LSUtil.rdm_inst:random(3) == 3
	local useBoth = LSUtil.rdm_inst:random(10) == 10
	if useSuffix or useBoth then suffix = " "..getText("IGUI_GnomesSuffix_"..tostring(LSUtil.rdm_inst:random(30))); end
	if not useSuffix or useBoth then preffix = getText("IGUI_GnomesPrefix_"..tostring(LSUtil.rdm_inst:random(30))).." "; end
	--print("gnome name is "..preffix..name..suffix)
	return preffix..name..suffix
end

function LSIWAction:gnome() -- gnomes can only happen during production of curios or toys (of level 5 or higher) and replace the result entirely, consuming resources spent (a gnome effect plays instead of fireworks)
	local charData = self.character:getModData()
	charData.LSCooldowns['invGnome'] = LSUtil.rdm_inst:random(24,48)

	self.gnomeSpawn = true
	self.luckArgs = {"Gnome",false,true,{"LS_Gnomes_"..tostring(LSUtil.rdm_inst:random(2,15)),"obj"},false}
	self['updateWorkbench'](self)
end

local rollData = {
	['good'] = {"chance","chanceBig","chanceGnome"},
	['bad'] = {"chance","chanceBig"},
}

function LSIWAction:rollChance()
	local objData = self.obj:getModData()
	local eventData = objData['events']
	local newDuration = self.duration
	eventData['good'] = eventData['good'] or {}
	local dataGood = eventData['good']
	eventData['bad'] = eventData['bad'] or {}
	local dataBad = eventData['bad']
	dataGood['num'] = dataGood['num'] or 0
	dataBad['num'] = dataBad['num'] or 0
	local forced = dataGood['force'] or dataBad['force']
	if not forced and (self.skillLevel == 0 or dataGood["Focus"]) then return; end

	local limit = (forced and 10) or (objData.duration > 20000 and 4) or (objData.duration > 9000 and 3) or (objData.duration > 2000 and 2) or 1
	if dataGood['num']+dataBad['num'] >= limit then return; end -- max event limit per phase
	
	local percent = getPhaseProgress(objData.duration, self.duration-self.jobProgress)
	eventData['target'] = eventData['target'] or {}
	local lastTarget
	-- rolls at 15%, 33%, 50% and 70% (saved in objData.events.target)
	for n=1,#self.thresholds do
		local target = self.thresholds[n]
		if not eventData['target'][n] then
			if percent+2 >= target or (percent > target and percent-5 <= target) then -- if its about to pass target OR if it has just passed target (during the rollDelay interval)
				eventData['target'][n] = true
				lastTarget = n
			end -- no breaks, in case a progress jump triggers multiple targets
		end
	end
	if not lastTarget then return; end
	dataGood['chance'] = (self.skillLevel < 2 and 0) or dataGood['chance'] or 5
	dataGood['chanceBig'] = (dataGood['chanceBig'] and math.max(1,dataGood['chanceBig'])) or 1
	dataGood['chanceGnome'] = (dataGood['chanceGnome'] and math.max(1,dataGood['chanceGnome'])) or 1
	dataBad['chance'] = dataBad['chance'] or 5
	dataBad['chanceBig'] = (dataBad['chanceBig'] and math.max(1,dataBad['chanceBig'])) or 1
	-- first rolls 100 and if it gets >60 then rolls chance
	local rollKarma, rollName
	local canCrit = true
	if forced or LSUtil.rdm_inst:random(100) > 60 then
		local charData = self.character:getModData()
		-- crits can't happen for lesser projects; crits can never happen in the first phase (except production); min skill level 5 to crit
		canCrit = not eventData['crit'] and self.skillLevel >= 5 and objData['level'] > 3 and lastTarget >= 3 and not self.isSchematics
		if not canCrit then dataGood['chanceBig'] = 0; dataBad['chanceBig'] = 0; end
		-- gnome 1% (0 if a gnome was created recently or if threshold < 50)
		local canGnome = self.skillLevel >= 5 and not self.isInv and lastTarget >= 2 and
		(self.workParams[2] == "Production" or (self.workParams[2] == "Invention" and self.workParams[1] > 1)) and
		(not charData.LSCooldowns['invGnome'] or charData.LSCooldowns['invGnome'] <= 0)
		if not canGnome then dataGood['chanceGnome'] = 0; end
		
		for k, v in pairs(rollData) do
			for n=1,#v do
				if rollName then break; end
				local data = v[n]
				local chance = eventData[k][data]
				local forceEvent = eventData[k]['force'] and eventData[k]['force'] == n
				if forceEvent or (chance > 0 and LSUtil.rdm_inst:random(100) <= chance) then
					rollName = data
					rollKarma = tostring(k)
					if forceEvent then eventData[k]['force'] = false; end
					break
				end
			end
		end
	end
	-- chance of good or bad roll increases after an empty roll (big +1, small+5), bad decreases after a bad or good roll, good decreases after a good roll
	if rollKarma then
		dataGood['chance'] = 5
		dataGood['chanceBig'] = 1
		if rollKarma == "good" or dataGood["FocusGood"] then
			if dataGood["FocusGood"] then dataBad['chance'] = 5; end
			if rollName == "chanceGnome" then
				dataGood['chanceGnome'] = 0
				self['gnome'](self)
			elseif rollName == "chanceBig" then
				self['luckBig'](self)
			else
				self['luckSmall'](self, dataGood["FocusGood"])
			end
		elseif not eventData['Lucky'] then
			dataBad['chance'] = 5
			dataBad['chanceBig'] = 1
			if rollName == "chanceBig" then
				self['failBig'](self)
			else
				self['failSmall'](self)
			end
		else
			eventData['Lucky'] = false
			getSoundManager():playUISound("UI_Painting_Complete")
			doNote(self.character, " <RGB:0.7,1,0.7><CENTRE>"..getText("IGUI_InvWorkbench_LuckSmall").." <LINE><TEXT>"..getText("IGUI_InvWorkbench_LuckSmall_Lucky_trigger"), "media/ui/lucky_legacy.png", 100)
		end
		return
	end
	
	-- crit bad and good min 1% max 3% (0 if a big roll happened in any phase), bad and good min 5% max 20%, otherwise nothing happens
	dataGood['chance'] = math.min(25,dataGood['chance']+2)
	dataBad['chance'] = math.min(25,dataBad['chance']+2)
	if canCrit then
		dataGood['chanceBig'] = math.min(5,dataGood['chanceBig']+1)
		dataBad['chanceBig'] = math.min(5,dataBad['chanceBig']+1)
	end
	dataGood['chanceGnome'] = math.min(3,dataGood['chanceGnome']+1)
	-- saves progress
	self['updateWorkbench'](self)
	
	-- a ProgressBig roll cancels the next roll

end

function LSIWAction:resetAll()
	self.fakeDelta = 0; self.jobProgress = 0
	self:resetPhases(false,true) -- {"a","b",...}, all phases
end

function LSIWAction:endInteraction()
	self['grantXP'](self)
	local sex = (self.character:isFemale() and "Woman") or "Man"
	self.animVars = {anim="Bob_Converse_Listening01",countTotal=6,soundTime=false,soundName=sex.."IntriguedHMM0",soundVar=9}
	stopSound(self.character, self.sound)
	self:setOverrideHandModels(nil, nil)
	
	self:setActionAnim(self.animVars.anim)
	
	self.duration = self.duration-self.jobProgress
	--LSUtil.debugPrint("LSIWAction:endInteraction(), new duration is "..tostring(self.duration))
	if self.character:isTimedActionInstant() or self.duration <= 0 then
		self:forceComplete()
	else
		if isClient() then
			local objData = self.obj:getModData()
			objData.progress = self.duration
			sendClientCommand("LS", "ModifyObjData", {{self.obj:getX(),self.obj:getY(),self.obj:getZ(),self.obj:getSprite():getName()}, false, objData})
		end
	end

end

function LSIWAction:resetPhases(list, all)
	for _, phase in ipairs(self.phases) do
		if self.phaseStates[phase.name] and (all or list and list[phase.name]) then
			self.phaseStates[phase.name] = false
		end
	end
end

local interactionsTable = {
	Assemble = {anim="Bob_Inv_Assemble",countTotal=3,soundTime=35,soundName="InvWorkbench_Tend",propL="CraftingMetalPart",propR=false},
	BlastMetal = {anim="Bob_Inv_BlastMetal",countTotal=false,soundTime=false,soundName=false,soundVar=false,propL=false,propR="ScrapMetal"},
	BlastRandom = {anim="Bob_Inv_BlastRandom",countTotal=false,soundTime=false,soundName=false,soundVar=false,propL="ClubHammer",propR=false}, -- {"BreakMetalItem","BuildMetalStructureSmallScrap","BuildMetalStructureLargeWiredFence","BreakGlassItem","BreakWoodItem"}
	BlowPipe = {anim="BlowGlass",countTotal=3,soundTime=40,soundName="MakeFireNotchedPlank",propL=false,propR="CraftingGlassBlowPipe"},
	BlowTorch = {anim="Bob_Sculpt_Metal_Action",countTotal=1,soundTime=false,soundName="BlowTorch",propL="BlowTorch",propR=false},
	Chisel = {anim="Bob_Inv_Chisel",countTotal=false,soundTime=false,soundName=false,soundVar=false,propL="ClubHammer",propR="MasonsChisel"},
	Cut = {anim="RipSheets",countTotal=3,soundTime=false,soundName="ClothesRipping",propL=false,propR="BurlapPiece"},
	CutWire = {anim="CutWire",countTotal=3,soundTime=false,soundName="Knitting",propL="CraftingPliers",propR="CraftingWire"},
	Craft1H = {anim="Bob_Inv_Craft1H",countTotal=false,soundTime=false,soundName=false,propL=false,propR="SharpenBladeGrindstone"}, --CrudeSwordBlade
	Craft2H = {anim="Bob_Inv_Craft2H",countTotal=3,soundTime=false,soundName="InvWorkbench_Tend",soundVar=3,propL=false,propR=false},
	Disassemble = {anim="Bob_Inv_Disassemble",countTotal=2,soundTime=false,soundName="RepairWithWrench",propL="Screwdriver_Red",propR="CraftingMetalPart"},
	DisassembleElec = {anim="Bob_Inv_DisassembleElec",countTotal=2,soundTime=false,soundName="Dismantle",propL="Screwdriver_Red",propR=false},
	Hammer = {anim="Bob_Inv_Hammer",countTotal=2,soundTime=10,soundName="Hammering",propL="Hammer",propR=false},
	HammerMetal = {anim="HammerSmashSurface",countTotal=2,soundTime=10,soundName="SmashMetalHit",propL="ClubHammer",propR=false},
	Lathe = {anim="Bob_Inv_Lathe",countTotal=1,soundTime=false,soundName="RepairWithWrench",propL=false,propR=false},
	Make = {anim="Bob_Inv_Make",countTotal=3,soundTime=35,soundName="InvWorkbench_Tend",soundVar=3,propL=false,propR="Receiver",research=true},
	MakeElec = {anim="Bob_Inv_MakeElectric",countTotal=3,soundTime=20,soundName=false,soundVar={"Dismantle","VehicleHotwireStart","BuildMetalStructureSmallWiredFence","GeneratorRepair","GeneratorConnect"},propL=false,propR="Receiver"},
	MakeMetal = {anim="Bob_Inv_MakeMetal",countTotal=3,soundTime=false,soundName="SharpenBladeWhetstone",propL="ScrapMetal",propR="CraftingMetalPart"},
	MixFluids = {anim="Bob_Inv_MixFluids",countTotal=false,soundTime=false,soundName=false,propL="BottleCrafted_Ground",propR="JarCrafted_Ground",research=true}, -- okay
	MixMortar = {anim="Bob_Inv_MixMortar",countTotal=1,soundTime=false,soundName="CraftMakeCement",propL="BottleCrafted_Ground",propR="Mortar_Ground",research=true}, -- okay
	SawMetal = {anim="SawSmallItemMetal",countTotal=false,soundTime=false,soundName=false,propL="Hacksaw",propR="SteelBarStockHalf"},
	--SawMetalB = {anim="SawOffShotgun",countTotal=3,soundTime=false,soundName="Sawing",propL="Hacksaw",propR=false},
	Tying = {anim="Bob_Inv_Tying",countTotal=1,soundTime=false,soundName="CraftSheetSlingBag",propL=false,propR="Twine"},
	Welding = {anim="Bob_Inv_Welding",countTotal=1,soundTime=false,soundName=false,propL="Wrench",propR="CraftingWeldingPipe"},
	WoodRod = {anim="Bob_Inv_WoodRod",countTotal=1,soundTime=60,soundName="CraftWeaponSpearWood",propL=false,propR=false},
	ReadBook = {anim="Bob_ReadBook",countTotal=false,soundTime=false,soundName=false,propL=false,propR="Book",researchOnly=true},
	WriteBook = {anim="Bob_WriteBook",countTotal=1,soundTime=false,soundName="WriteSongPencil",propL="Pencil",propR="Book",researchOnly=true},
}

local function getInteractionArgs(action)
	return interactionsTable[action]
end

local function updateOverlaySprite(obj, overlays, oldOverlay)
	if not oldOverlay or LSUtil.rdm_inst:random(10) == 1 then
		local newOverlay = LSUtil.getNewParam(oldOverlay, overlays)
		if isClient() then
			sendClientCommand("LS", "ModifyOverlaySprite", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()}, newOverlay})
		else
			obj:setOverlaySprite(newOverlay, true)
		end
		return newOverlay
	end
	return oldOverlay
end

function LSIWAction:doInteraction()
	
	stopSound(self.character, self.sound)

	self.bubbleSound = false

	self.currentAction = LSUtil.getNewParam(self.currentAction, self.actionTable)
	
	self.animVars = getInteractionArgs(self.currentAction)

	self.currentOverlay = updateOverlaySprite(self.obj, self['overlays'..self.facing], self.currentOverlay)
	--self.soundName = LSUtil.getNewParam(self.soundName, self.soundTable[self.soundGroup])
	--self.sound = self.character:getEmitter():playSound(self.soundName)
	
	--self.character:Say("Now Running "..self.animVars.anim)
	
	self:setActionAnim(self.animVars.anim)
	self:setOverrideHandModels(self.animVars.propL, self.animVars.propR)
end

local function getTotalEfficiency(base, t)
	for n=1, #t do
		base = base+t[n]
	end
	return math.min(base, 6)
end

function LSIWAction:start()

	self.fakeMax = 1100
	self.fakeDelta = 0
	self.deltaAdd = 0

	self:setOverrideHandModels(nil, nil)
	self:setActionAnim(self.animVars.anim)
	self.sound = self.character:playSound("PutItemInBag")
	
	self.phases = {
		{name="a",threshold=0.02,handler="doInteraction"},
		{name="b",threshold=0.04,handler="splashEffect"},
		{name="c",threshold=0.10,handler="splashEffect"},
		{name="d",threshold=0.16,handler="splashEffect"},
		{name="e",threshold=0.20,handler="splashEffect"},
		{name="f",threshold=0.26,handler="endInteraction"},
		{name="g",threshold=0.29,handler="resetAll"},
	}
	--self.soundTable = getNewSoundTable(self.sex)

	local objData = self.obj:getModData()
	if not objData.duration then
		local newDuration = self.duration
		objData.duration = newDuration
	end

	for k, v in pairs(interactionsTable) do
		if (self.isSchematics and (v.research or v.researchOnly)) or (not self.isSchematics and not v.researchOnly) then
			table.insert(self.actionTable,tostring(k))
		end
	end

	--self['cacheSprites'](self)

end

local function doWarn(character, x, y, title, text, soundName)
	local newPanel = LSWarn:new(character, x, y, title, text, soundName);
	newPanel:initialise()
	newPanel:addToUIManager()
end

function LSIWAction:stop()
	stopSound(self.character, self.sound)
	self['removeSplashObj'](self)
	local objData = self.obj:getModData()
	local eventData = objData['events']
	local newDuration = math.max(10, self.duration-self.jobProgress)
	--self.failArgs = {failType,newDuration,mentalBlock,bummedChance==0 and 0.4,addCosts,nil}
	if self.failArgs then
		local charData = self.character:getModData()
	
		newDuration = self.failArgs[2] or newDuration
		charData.LSCooldowns['mentalBlock'] = self.failArgs[3] or 0
		charData.LSMoodles["Gloomy"].Value = self.failArgs[4] or 0
		if self.failArgs[5] and objData.costFail then objData.workCost = LSUtil.deepCopy(objData.costFail); end
		
		local soundName
		local title = "Small"
		if self.failArgs[6] then -- crit
			soundName = "UI_sting_somber"..tostring(LSUtil.rdm_inst:random(2))
			title = "Big"
			eventData['crit'] = self.failArgs[1]
		end
		soundName = soundName or "UI_sting_fail"..tostring(LSUtil.rdm_inst:random(4))
		
		local gloomy = (self.failArgs[4] and " <LINE>"..getText("IGUI_InvWorkbench_Fail"..title.."_Bummed")) or ""
		doWarn(self.character, 100, 86, getText("IGUI_InvWorkbench_Fail"..title), getText("IGUI_InvWorkbench_Fail"..title.."_"..self.failArgs[1])..gloomy,soundName)
		
		eventData['bad'] = eventData['bad'] or {}
		eventData['bad']['num'] = (eventData['bad']['num'] and eventData['bad']['num']+1) or 1
		eventData['bad'][self.failArgs[1]] = true
		
		if self.failArgs[1] == "Ruined" then objData.isRuined = true; end
		
		LSSync.updateClientData(self.character, charData)
	end
	
	LSUtil.debugDiagnostics("/shared/TimedActions/LSIWAction", "LSIWAction:stop",{
	['objData.progress']=objData.progress,
	['newDuration']=newDuration,
	['self.duration']=self.duration,
	})
	objData.progress = newDuration
	if isClient() then sendClientCommand("LS", "ModifyObjData", {{self.obj:getX(),self.obj:getY(),self.obj:getZ(),self.obj:getSprite():getName()}, false, objData}); end

	if self.failArgs and self.failArgs[1] == "Explosion" then self['explosionEffect'](self); end

    ISBaseTimedAction.stop(self);		
end

local function getNewSpriteAndOverlay(key)
	local t = {
		LS_Inventions_10 = {"LS_Inventions_4","LS_Inventions_8","LS_Inventions_6"},
		LS_Inventions_11 = {"LS_Inventions_5","LS_Inventions_9","LS_Inventions_7"},
	}
	return t[key][1], t[key][2], t[key][3]
end

local function isFinished(newPhase,workType,complex)
	return newPhase > 3 or
	workType == "Production" or
	(workType == "Research" and newPhase > 2) or
	(workType == "Invention" and newPhase > 2 and not complex)
end

function LSIWAction:advanceProject()
	local objData = self.obj:getModData()
	objData.progress = false; objData.duration = false; objData.workCost = false; objData.costFail = false; objData.events.bad = false; objData.events.good = false; objData.events.target = false
	local newPhase = math.floor(self.workParams[1]+1)
	local newSprite, newOverlay, finishedOverlay = getNewSpriteAndOverlay(self.spriteName)
	local finished = isFinished(newPhase,self.workParams[2],self.isInv)
	if self.workParams[2] == "Research" and finished then
		newOverlay = false
		local keys = {'lsWkID','author','workPhase','workType','invName','resultType','result','isRuined','events','itemCustomName'}
		for n=1,#keys do
			local key = keys[n]
			objData[key] = false
		end
		if not isClient() then
			self.obj:setOverlaySprite(false, true)
			self.obj:setSprite(newSprite)
		end
	else
		if self.gnomeSpawn then objData.itemCustomName = getGnomeName(); end
		newSprite = false
		objData.workPhase = newPhase
		if finished then newOverlay = finishedOverlay; end
		if not isClient() then self.obj:setOverlaySprite(newOverlay, true); end
	end
	if isServer() then
		self.obj:transmitUpdatedSpriteToClients()
		self.obj:transmitModData()
	elseif isClient() then
		sendClientCommand("LS", "ModifyObjData", {{self.objX,self.objY,self.objZ,self.obj:getSprite():getName()}, false, objData})
		if newSprite then
			sendClientCommand("LS", "ModifySprite", {{self.objX,self.objY,self.objZ,self.obj:getSprite():getName()}, newSprite, newOverlay})
		else
			sendClientCommand("LS", "ModifyOverlaySprite", {{self.objX,self.objY,self.objZ,self.obj:getSprite():getName()}, newOverlay})
		end
	else
		self.obj:setOverlaySprite(newOverlay or "", true)
		if newSprite then self.obj:setSprite(newSprite); end
	end
end

local function getInvSpriteName(name)
	for k, v in pairs(InventionsMenu.workbench.invLib) do
		if v.invName == name then return v.invResult; end
	end
	return false
end

local function getMaxPhases(workType, isInv)
	if workType == "Invention" then return "???"; end
	local t = {
		Production = 1,
		Research = 2,
		Invention = 3,
	}
	local maxNum = (isInv and 2) or 3
	return math.min(maxNum,t[workType])
end

function LSIWAction:perform()
	stopSound(self.character, self.sound)
	self['removeSplashObj'](self)
	local phase, invName, invType, result = self.workParams[1], self.workParams[3], self.workParams[4], self.workParams[5]
	local isObj = invType == "obj" or invType == "invObj"
	local isResearch = self.workParams[2] == "Research"
	local noteText, noteTex, overlay, showInv, soundName, improvLvl
	local charData = self.character:getModData()
	local charInvData = charData['invData']
	local addW, xpBonus = 0, 0
	local completed = isFinished(math.floor(phase+1),self.workParams[2],self.isInv)
	if completed then
		xpBonus = 10
		self['fireworksEffect'](self)
		showInv = true
		noteText = " <RGB:0.7,1,0.7><CENTRE>"..getText("IGUI_InvWorkbench_Completed_"..self.workParams[2])
		if self.workParams[2] == "Invention" and not self.gnomeSpawn then
			soundName = "UI_Invention_New"
			if not charInvData[invName] then
				local path = (self.isInv and "invLib") or "toysLib"
				local invParams = InventionsMenu.workbench.getInvFromTable(path, invName)
				if self.isInv then
					InventionsMenu.workbench.addInventionToPlayer(charInvData, invParams)
				else
					charInvData[invName] = LSUtil.deepCopy(invParams)
				end
				local worldHours = getGameTime():getWorldAgeHours()
				charInvData[invName]['lastCreated'] = worldHours
				charInvData[invName]['numCreated'] = 1
				
				charData.LSMoodles["Eureka"].Value = (self.isInv and 0.8) or 0.4
				xpBonus = 25
				
				if invName == "ScrapBushSeed" then LSUtil.LearnRecipes(self.character, {"lifestyle:scrap bush growing season"}); end
			end
		elseif isResearch then
			charData.LSMoodles["Eureka"].Value = 0.8
			xpBonus = 15
			soundName = "UI_Invention_Improved"
			charInvData[invName]['workCost'] = false
			charInvData['lsWkID'] = false
			local invData = charInvData[invName]
			local improvData = invData['improvementData']
			improvLvl = tostring(improvData[result][1]+1)
			local total = improvData[result][2]
			local newVal = math.min(math.floor(improvData[result][1]+1), total)
			improvData[result] = {newVal, total}
			
			local invImprovDefs = LSUtil.deepCopy(LSInventionDefs.Improvements[invName])
			-- check for improvements
			local newCostPenalty, impNum = 1, 0
			for k, v in pairs(improvData) do
				local val = v[1]
				if val > 0 then
					local key = invImprovDefs[k]
					if key then
						local cost
						if key.repeatable then -- several levels
							invData['inventionData'][k] = key.repeatable[val]
							if key.special then 
								cost = LSInventionDefs.ImprovCost['addRS']*val
							else
								cost = LSInventionDefs.ImprovCost['addR']*val
							end
						else -- only 1 level, use result (implied, since value is higher than 0)
							invData['inventionData'][k] = key.result
							if key.special then 
								cost = LSInventionDefs.ImprovCost['addS']
							else
								cost = LSInventionDefs.ImprovCost['add']
							end
						end
						if tostring(k) ~= "costDecrease" then
							newCostPenalty = newCostPenalty+cost
							if tostring(k) ~= "standardization" then
								impNum = impNum+val
							end
						end
					end
				end
				if tostring(k) == "efficiency" then -- special improvement that multiplies other params
					for n=1, #invData['inventionData']['efficiencyBase'] do
						invData['inventionData']['efficiencyMult'][n] = invData['inventionData']['efficiencyBase'][n]*invData['inventionData']['efficiency']
					end
				end
			end

			if impNum and impNum >= LSInventionDefs.ImprovCost['numPenalty'] then
				newCostPenalty = newCostPenalty+(math.floor(impNum/LSInventionDefs.ImprovCost['numPenalty'])*LSInventionDefs.ImprovCost['addR'])
			end
			if newCostPenalty and newCostPenalty ~= invData['inventionData']['costPenalty'] then invData['inventionData']['costPenalty'] = newCostPenalty; end

		elseif not self.gnomeSpawn then -- Production
			local addNum = (charInvData[invName]['numCreated'] and charInvData[invName]['numCreated']+1) or 1
			charInvData[invName]['numCreated'] = addNum
			noteText = noteText.." <LINE><RGB:0.7,0.7,0.7>"..getText("IGUI_InvWorkbench_Production_Copy",charInvData[invName]['numCreated'])
			soundName = "UI_Invention_Copy"..tostring(LSUtil.rdm_inst:random(2))
			if invName == "ScrapBushSeed" then LSUtil.LearnRecipes(self.character, {"lifestyle:scrap bush growing season"}); end
		else
			xpBonus = 100
		end
		
		xpBonus = (self.isInv and self.objData.level*(xpBonus*2)) or self.objData.level*xpBonus
	else -- not finished
		local nextPhase = phase+1
		noteText = " <TEXT>"..getText("Tooltip_InvWorkbench_"..self.workParams[2].."_b"..tostring(phase)).." <LINE><LINE><RGB:0.8,0.8,0.8><CENTRE>"..
		getText("Tooltip_InvWorkbench_Phase",nextPhase,getMaxPhases(self.workParams[2], self.isInv))..getText("Tooltip_InvWorkbench_"..self.workParams[2].."_a"..tostring(nextPhase))
	
		if isResearch then
			showInv = true
			improvLvl = tostring(charInvData[invName]['improvementData'][result][1]+1)
			--soundName = 
		elseif self.workParams[2] == "Invention" then
			noteTex = "media/ui/IW_icon.png"
		end
	
	end

	if isResearch then
		addW = 100
		local improvName = "IGUI_Inventions_"..invName.."_"..result
		if getText(improvName) == "IGUI_Inventions_"..invName.."_"..result then improvName = "IGUI_Inventions_"..result; end
		noteText = " <RGB:1,1,0.7>"..getText(improvName).." <SPACE> ("..improvLvl..")".." <LINE>"..noteText
		if completed then noteText = noteText.." <LINE><TEXT>"..getText(improvName.."_desc").." <LINE><CENTRE><RGB:1,1,1>"..getText(improvName.."_desc_short"); end
	end

	if showInv and not self.gnomeSpawn then
		local name, tex
		local spriteName = (isResearch and getInvSpriteName(invName)) or result
		if isObj then
			name = LSUtil.getMoveableDisplayName(spriteName, nil, nil, nil, spriteName)
			spriteName = (spriteName == "LS_Inventions_12" and "LS_Inventions_32") or spriteName
			local sprite = getTexture(spriteName)
			if sprite then tex = sprite:splitIcon(); end
			noteTex = (tex and tex:getName()) or spriteName
		else
			tex, name = LSUtil.getItemTexAndTextNew(spriteName)
			noteTex = (tex and tex:getName()) or "media/ui/okayNo_icon.png"
		end
		noteText = " <CENTRE><RGB:1,1,1>"..name.." <LINE>"..noteText
	end

	if self.luckArgs and self.luckArgs[3] then -- finished instantly
		addW = 100
		if self.gnomeSpawn then
			soundName = (LSUtil.rdm_inst:random(2) == 1 and "UI_sting_mystical_good1") or "UI_sting_mistery"
			noteTex = "media/ui/Traits/trait_kook.png"
			noteText = "<CENTRE><RGB:0.9,0.8,1>"..getText("IGUI_InvWorkbench_Completed_Gnome")
		else
			local title = (self.luckArgs[5] and "Big") or "Small"
			noteText = noteText.." <LINE><TEXT><RGB:0.7,0.7,1>"..getText("IGUI_InvWorkbench_Luck"..title).." - <SPACE><RGB:0.7,0.7,0.7>"..getText("IGUI_InvWorkbench_Luck"..title.."_"..self.luckArgs[1])
		end
	end

	self['grantXP'](self, xpBonus)

	if soundName then getSoundManager():playUISound(soundName); end
	doNote(self.character, noteText, noteTex, addW)

	LSSync.updateClientData(self.character, charData)

	self['advanceProject'](self)

	ISBaseTimedAction.perform(self);
end

function LSIWAction:complete()
	--self['advanceProject'](self)
	return true
end

function LSIWAction:getDuration()
	return -1
end

local function getWorkbenchOverlays(isSchematics)
	if isSchematics then return {"LS_Inventions_36","LS_Inventions_38","LS_Inventions_40","LS_Inventions_42"}, {"LS_Inventions_37","LS_Inventions_39","LS_Inventions_41","LS_Inventions_43"}; end
	return {"LS_Inventions_24","LS_Inventions_26","LS_Inventions_28","LS_Inventions_30"}, {"LS_Inventions_25","LS_Inventions_27","LS_Inventions_29","LS_Inventions_31"}
end

-- groups Production, Research and Inventing
function LSIWAction:new(character, obj, args)  -- objData, duration, material list, spriteName, toolList, hasWork (if not emptySprite then replaces obj sprite), skillLevel, workParams (phase,workType,invName,invType,invResult)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.obj = obj
	o.args = args
	o.objData = o.args[1]
	o.duration = o.args[2]
	o.matList = o.args[3]
	o.spriteName = o.args[4]
	o.toolList = o.args[5]
	o.emptySprite = o.args[6]
	o.skillLevel = o.args[7]
	o.workParams = o.args[8]
	o.skillBoost = 1
	o.thresholds = {15,33,50,70}
	--if not o.emptySprite then o.newSprite, o.overlay = getNewSpriteAndOverlay(o.spriteName, o.workParams[2]); end
	o.ignoreDynamicTime = true
    o.stopOnWalk        = true
    o.stopOnRun         = true
	o.stopOnAim         = true
	o.maxTime = o:getDuration()
	o.facing = (o.spriteName == "LS_Inventions_10" and "E") or "S"
	o.isInv = LSUtil.StringStartWith(o.workParams[4],"inv")
	o.isSchematics = o.workParams[2] ~= "Production" and o.workParams[1] < 2
	o.overlaysE, o.overlaysS = getWorkbenchOverlays(o.isSchematics)
	o.jobProgress = 0
	o.jobTotal = 0
	o.phases = false
	o.phaseStates = {}
	o.actionTable = {}
	o.splashTable = {"Smoke_A","Smoke_B","Smoke_Black_A","Smoke_Black_B"}
	o.splashSounds = {"BreakMetalItem","BuildMetalStructureSmallScrap","BuildMetalStructureLargeWiredFence","BuildMetalStructureSmall","SmashMetalHit"}
	o.objX = o.obj:getX()
	o.objY = o.obj:getY()
	o.objZ = o.obj:getZ()
	--o.spriteCache = {}
	o.currentAction = false
	o.tileSqr = o.obj:getSquare()
	o.animVars = {anim="Loot",countTotal=false,soundName="PutItemInBag",soundTime=false}
	o.sound = 0
	o.soundName = "none"
	o.exerciseMetabolics = "UsingTools"
	return o;
end
