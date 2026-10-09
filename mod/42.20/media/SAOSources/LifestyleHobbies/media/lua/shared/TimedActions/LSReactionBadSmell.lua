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

LSReactionBadSmell = ISBaseTimedAction:derive("LSReactionBadSmell")

local function LSReactiongetSoundIdxEnd(character)
	if character:isFemale() then
		return {"Woman_Yuck01","Woman_Yuck02","Woman_Yuck03","Woman_Yuck04","Woman_Yuck05","Woman_Yuck06","Woman_Yuck07","Woman_Yuck08","Woman_Yuck09","Woman_Yuck10"}
	else
		return {"Man_Yuck01","Man_Yuck02","Man_Yuck03","Man_Yuck04","Man_Yuck05","Man_Yuck06","Man_Yuck07","Man_Yuck08"}
	end
end

local function LSReactiongetNewSoundByName(character)
	local newSound = LSReactiongetSoundIdxEnd(character)
	local idxS = ZombRand(#newSound) + 1
	return newSound[idxS]
end

local function LSReactionGetAnim()
	local anim, dice2 = "Bob_SmellBad", ZombRand(2)
	if dice2 == 0 then anim = "Bob_SmellGag"; end
	return anim
end

function LSReactionBadSmell:isValid()
	return true
end

function LSReactionBadSmell:update()


end

function LSReactionBadSmell:start()
	local anim = LSReactionGetAnim()
	self:setActionAnim(anim)
	local sound = LSReactiongetNewSoundByName(self.character)
	self.gameSound = self.character:getEmitter():playSound(sound);
end

function LSReactionBadSmell:stop()

	if self.gameSound and
	self.gameSound ~= 0 and
	self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

    ISBaseTimedAction.stop(self);
end

function LSReactionBadSmell:perform()
	ISBaseTimedAction.perform(self);
end

function LSReactionBadSmell:complete()
	return true
end

function LSReactionBadSmell:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 60
end

function LSReactionBadSmell:new(character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
	o.stopOnAim = true
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	return o;
end
