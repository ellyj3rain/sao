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

LSInvNeuralHatPress = ISBaseTimedAction:derive("LSInvNeuralHatPress");

function LSInvNeuralHatPress:isValid()
	return not self.invData['isBroken'] and self.target ~= 2 and self.target ~= self.current and ((self.current == 0 and self.target == 1) or self.invData['running'])
end

function LSInvNeuralHatPress:waitToStart()
	self.action:setUseProgressBar(false)
	return false
end

function LSInvNeuralHatPress:update()
	if self.jobProgress < (self.maxTime*0.5) then
		self.jobProgress = self:getJobDelta()*self.maxTime
	elseif not self.secondPhase then
		self.secondPhase = true
		self.sound = self.character:getEmitter():playSound("Gadget_START_SHORT")
	end

end

function LSInvNeuralHatPress:start()
	self:setOverrideHandModelsString("RemoteController", nil)
	self:setActionAnim("Bob_PressRemote")
	self.character:getEmitter():playSound("PutItemInBag")
end

function LSInvNeuralHatPress:stop()
	if self.sound and self.sound ~= 0 and self.character:getEmitter():isPlaying(self.sound) then
		self.character:getEmitter():stopSound(self.sound);
	end
    ISBaseTimedAction.stop(self);		
end

function LSInvNeuralHatPress:perform()
	if self.target >= 3 or (self.current >= 3 and self.target == 1) then
		LSUtil.playSoundCharacter(character, "Gadget_WOOSH", nil, nil, true, nil, {false,0.3*self.target}, nil) -- character, soundName, soundVar, loopMins, transmit, proxy, soundArgs, noiseArgs
		self.invData['recentActive'] = 2
		LSInv.doDataTransmit(self.item, self.invData)
	else
		local turnOff = self.target == 0
		local endSound = (turnOff and "FortuneTeller_PowerDown") or "FortuneTeller_PowerOn"
		self.invData['running'] = not turnOff
		LSInv.doDataTransmit(self.item, self.invData)		
		self.character:getEmitter():playSound(endSound)
	end
	--LSUtil.changeTexture_Item(self.character, self.item, self.target)
	self.item:getVisual():setTextureChoice(self.target)
	if LSSync.isNotServer() then self.character:resetModel(); end
	ISBaseTimedAction.perform(self);
end

function LSInvNeuralHatPress:complete()
	self.item:getVisual():setTextureChoice(self.target)
	self.item:synchWithVisual()
	return true
end

function LSInvNeuralHatPress:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 160
end

function LSInvNeuralHatPress:new(character, item, invData, target, current)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.item = item
	o.invData = invData
	o.target = target
	o.current = current
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = true;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.secondPhase = false
	o.sound = 0
	return o;
end
