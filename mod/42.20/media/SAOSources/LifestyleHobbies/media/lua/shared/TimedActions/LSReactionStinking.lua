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

LSReactionStinking = ISBaseTimedAction:derive("LSReactionStinking")

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

local function LSReactionGetSoundSimple()
	local sound, dice2 = "Smell_Sniff01", ZombRand(2)
	if dice2 == 0 then sound = "Smell_Sniff02"; end
	return sound
end

function LSReactionStinking:isValid()
	return true
end

function LSReactionStinking:update()

	if self.doUtterance >= 9 then
		self.doUtterance = 0
		if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
			self.character:getEmitter():stopSound(self.gameSound);
		end
		local newSound = LSReactiongetNewSoundByName(self.character)
		self.gameSound = self.character:getEmitter():playSound(newSound);
	end
	if self.doUtterance ~= 0 then self.doUtterance = self.doUtterance + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck); end
end

function LSReactionStinking:start()
	self:setActionAnim("Bob_Stinking")
	
	local sound = LSReactionGetSoundSimple()
	self.gameSound = self.character:getEmitter():playSound(sound);
	
end

function LSReactionStinking:stop()

	if self.gameSound and
	self.gameSound ~= 0 and
	self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

    ISBaseTimedAction.stop(self);
end

function LSReactionStinking:perform()
	ISBaseTimedAction.perform(self);
end

function LSReactionStinking:complete()
	return true
end

function LSReactionStinking:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 140
end

function LSReactionStinking:new(character)
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
	o.doUtterance = 1
	return o;
end
