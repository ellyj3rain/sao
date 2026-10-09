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

LSEndIntDisappointed = ISBaseTimedAction:derive("LSEndIntDisappointed")

local function getAnimList(character, source, reaction)

	local AnimList = require("MPSocial/Anim/Talking")
	local availableAnims = {}

	for k,v in pairs(AnimList) do
		if source then
			if (reaction == "negativeReaction") and (v.Type == "EndAlone") and (v.Mood == "Negative") then
				table.insert(availableAnims, v)
			end
		end

	end

	return availableAnims

end

local function getVoxList(character, source, reaction)

	local VoxList
	local availableVox = {}

	VoxList = require("MPSocial/Vox/BaseUtterances")

	for k,v in pairs(VoxList) do
		if (reaction == "negativeReaction") and (v.Type == "Disappointed") then
			table.insert(availableVox, v)
		end
	end

	return availableVox

end

function LSEndIntDisappointed:waitToStart()

	return false
end

function LSEndIntDisappointed:isValid()
	return true
end

function LSEndIntDisappointed:update()

	self.character:nullifyAiming()

	if (self.character:pressedMovement(true)) and (isKeyDown(Keyboard.KEY_LSHIFT)) then
		--print("TA-LSEndIntDisappointed force stop")
		self:forceStop()
	end

end

function LSEndIntDisappointed:start()

	self:setOverrideHandModels(nil, nil)
	self.character:setBlockMovement(true)
	
	self.availableAnims = getAnimList(self.character, self.source, self.reaction)
	self.availableVox = getVoxList(self.character, self.source, self.reaction)
	

	local randomLine = ZombRand(#self.availableVox) + 1
	local sound = self.availableVox[randomLine].sound
	
	if self.character:getDescriptor():isFemale() then	
		sound = self.availableVox[randomLine].soundF
	end

	self.character:getEmitter():playSound(sound)

	local randomAnim = ZombRand(#self.availableAnims) + 1
	local anim = self.availableAnims[randomAnim].Anim
	self.animTime = self.availableAnims[randomAnim].Time

	self:setActionAnim(anim)
	
end

function LSEndIntDisappointed:stop()

	self.character:setBlockMovement(false)

    ISBaseTimedAction.stop(self);
end

function LSEndIntDisappointed:perform()

	self.character:setBlockMovement(false)
	ISBaseTimedAction.perform(self);
end

function LSEndIntDisappointed:complete()
	return true
end

function LSEndIntDisappointed:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 200
end

function LSEndIntDisappointed:new(character, source, args)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
	o.source = source
	o.args = args
	o.otherArg = args[2]
	o.reaction = args[1]
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	o.availableAnims = 0
	o.availableVox = 0
	o.animTime = false
	return o;
end

return LSEndIntDisappointed