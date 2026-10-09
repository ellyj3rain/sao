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

LSAnimTest = ISBaseTimedAction:derive("LSAnimTest")

function LSAnimTest:isValid()
	return true
end

function LSAnimTest:update()

	if isKeyDown(Keyboard.KEY_E) then
		self:setActionAnim(self.anim1)
		self.character:Say("Executing Anim "..self.anim1)
	elseif isKeyDown(Keyboard.KEY_R) then
		self:setActionAnim(self.anim2)
		self.character:Say("Executing Anim "..self.anim2)
	elseif isKeyDown(Keyboard.KEY_T) then
		self:setActionAnim(self.anim3)
		self.character:Say("Executing Anim "..self.anim3)
	elseif isKeyDown(Keyboard.KEY_Y) then
		self:setActionAnim(self.anim4)
		self.character:Say("Executing Anim "..self.anim4)
	end

end

function LSAnimTest:start()

	self:setActionAnim("Bob_Booing")
	
	--self.gameSound = self.character:getEmitter():playSound(sound);
	
end

function LSAnimTest:stop()

	if self.gameSound and
		self.gameSound ~= 0 and
		self.character:getEmitter():isPlaying(self.gameSound) then
		self.character:getEmitter():stopSound(self.gameSound);
	end

    ISBaseTimedAction.stop(self);
end

function LSAnimTest:perform()
	ISBaseTimedAction.perform(self);
end

function LSAnimTest:complete()
	return true
end

function LSAnimTest:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 3000
end

function LSAnimTest:new(character)
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
	o.anim1 = "Bob_SmellBad"
	o.anim2 = "Bob_SmellGag"
	o.anim3 = "Bob_HoldBridgeNose"
	o.anim4 = "Bob_HoldBridgeNose2H"
	return o;
end
