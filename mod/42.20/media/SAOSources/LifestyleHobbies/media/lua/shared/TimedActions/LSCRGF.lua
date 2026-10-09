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

LSCRGF = ISBaseTimedAction:derive("LSCRGF")

local function getPropItem()
	local prop
	local items = getAllItems()
    for i=0, items:size()-1 do
        local item = items:get(i)
        if item and item:getFullName() and ((item:getFullName() == "Bell") or (item:getFullName() == "Base.Bell")) then
			prop = item:InstanceItem(item:getFullName())
			break
        end
    end
	return prop
end

function LSCRGF:isValid()
	return true
end

function LSCRGF:update()
	if self.character:isSitOnGround() then self:forceStop(); end


	if self.jobProgress > (self.maxTime*0.06) and (not self.startPhase) then
		self.startPhase = true
		if self.item then self:setOverrideHandModels(self.item:getWorldStaticItem(), nil); end
	elseif self.jobProgress > (self.maxTime*0.15) and (not self.turnOnSound) then
		self.turnOnSound = self.character:getEmitter():playSound("Gadget_START")
	elseif self.jobProgress > (self.maxTime*0.25) and (not self.turnOnSoundV) then
		self.turnOnSoundV = self.character:getEmitter():playSound("Vaccuum_START")
	end

	if self.jobProgress < (self.maxTime*0.3) then

	elseif self.jobProgress < (self.maxTime*0.75) then
		if not self.middlePhase then
			self.middlePhase = true
			self:setActionAnim("Bob_CleaningGFM")
			if self.actionSound and self.actionSound ~= 0 and self.character:getEmitter():isPlaying(self.actionSound) then
				self.character:getEmitter():stopSound(self.actionSound);
			end
			self.actionSound = self.character:getEmitter():playSound("Vaccuum_LOOP")
		end
	elseif not self.endPhase then
		self.endPhase = true
		self:setActionAnim("Bob_CleaningGFE")		
	end
	
	if self.endPhase and (self.jobProgress < (self.maxTime*0.78)) then
		if not self.turnOffSound then self.turnOffSound = self.character:getEmitter():playSound("Gadget_STOP"); end
	elseif self.endPhase and (self.jobProgress < (self.maxTime*0.85)) and (not self.lastSound) then
		self.lastSound = true
		if self.actionSound and self.actionSound ~= 0 and self.character:getEmitter():isPlaying(self.actionSound) then
			self.character:getEmitter():stopSound(self.actionSound);
		end
		self.actionSound = self.character:getEmitter():playSound("Vaccuum_STOP")
	end
	
	self.jobProgress = self:getJobDelta()*self.maxTime
end

function LSCRGF:start()
	self:setActionAnim("Bob_CleaningGF")

	self.item = getPropItem()
	self:setOverrideHandModels(nil, nil)
	self.actionSound = self.character:getEmitter():playSound("PutItemInBag")
end

function LSCRGF:stop()
	self:setOverrideHandModels(nil, nil)
	if self.actionSound and (self.actionSound ~= 0) and self.character:getEmitter():isPlaying(self.actionSound) then self.character:getEmitter():stopSound(self.actionSound); end
	if self.turnOnSound and self.character:getEmitter():isPlaying(self.turnOnSound) then self.character:getEmitter():stopSound(self.turnOnSound); end
	if self.turnOnSoundV and self.character:getEmitter():isPlaying(self.turnOnSoundV) then self.character:getEmitter():stopSound(self.turnOnSoundV); end
	self.character:getEmitter():playSound("Gadget_STOP")
	if self.middlePhase and (not self.endPhase) then self.character:getEmitter():playSound("Vaccuum_STOP"); end

    ISBaseTimedAction.stop(self);
end

function LSCRGF:perform()
	if self.actionSound and
	self.actionSound ~= 0 and
	self.character:getEmitter():isPlaying(self.actionSound) then
		self.character:getEmitter():stopSound(self.actionSound);
	end
	getSoundManager():playUISound("UI_CleanObject_Perform")
	self:setOverrideHandModels(nil, nil)

	local cooldownsData = self.character:getModData().LSCooldowns
	if cooldownsData then self.character:getModData().LSCooldowns['grimefighter'] = 24; end

	local square = getCell():getGridSquare(self.character:getX(), self.character:getY(), self.character:getZ())
  	for x = square:getX()-8,square:getX()+8 do
		for y = square:getY()-8,square:getY()+8 do
			local square = getCell():getGridSquare(x,y,self.character:getZ())
			if square then
				for i=0,square:getObjects():size()-1 do
					if square:haveBlood() then
						square:removeBlood(false, false)
					end
				end
			end
		end
	end
	--if isClient() then
		sendClientCommand("LS", "RemoveDirtTileDebug", {self.character:getX(), self.character:getY(), self.character:getZ(), 8})
	--end
	
	ISBaseTimedAction.perform(self);
end

function LSCRGF:complete()
	return true
end

function LSCRGF:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 600
end

function LSCRGF:new(character, ambt)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
	o.ambt = ambt
	o.item = false
	o.stopOnAim = true
	o.stopOnWalk = true
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = true
	o.soundName = "Hammering"
	o.soundTime = 0
	o.actionSound = 0
	o.jobProgress = 0
	o.turnOnSound = false
	o.turnOnSoundV = false
	o.turnOffSound = false
	o.lastSound = false
	o.startPhase = false
	o.middlePhase = false
	o.endPhase = false
	return o;
end

return LSCRGF