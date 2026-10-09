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

LSReactionFullBladder = ISBaseTimedAction:derive("LSReactionFullBladder")

function LSReactionFullBladder:isValid()
	return true
end

function LSReactionFullBladder:update()
	self.character:nullifyAiming()
end

function LSReactionFullBladder:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Bob_FullBladder")
	self.character:setBlockMovement(true)
end

function LSReactionFullBladder:stop()
	local whimperAudio = "FullBladder01_M"
	if self.character:isFemale() then whimperAudio = "FullBladder01_W"; end
	self.character:getEmitter():playSound(whimperAudio)
	self.character:setBlockMovement(false)
    ISBaseTimedAction.stop(self);
end

function LSReactionFullBladder:perform()
	local whimperAudio = "FullBladder01_M"
	if self.character:isFemale() then whimperAudio = "FullBladder01_W"; end
	self.character:getEmitter():playSound(whimperAudio)
	self.character:setBlockMovement(false)
	ISBaseTimedAction.perform(self);
end

function LSReactionFullBladder:complete()
	return true
end

function LSReactionFullBladder:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 100
end

function LSReactionFullBladder:new(character)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character;
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	return o;
end
