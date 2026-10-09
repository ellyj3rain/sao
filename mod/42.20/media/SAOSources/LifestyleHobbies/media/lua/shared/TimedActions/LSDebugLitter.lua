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

LSDebugLitter = ISBaseTimedAction:derive("LSDebugLitter")

function LSDebugLitter:isValid()
	return true
end

function LSDebugLitter:update()

end

function LSDebugLitter:start()


	
end

function LSDebugLitter:stop()



    ISBaseTimedAction.stop(self);
end

function LSDebugLitter:perform()

	local x = self.character:getX()
	local y = self.character:getY()
	local z = self.character:getZ()
	local SolidOrOverlay = self.litter
	local LitterSprite = self.spriteName

	sendClientCommand("LS", "DebugAddLitter", {x, y, z, SolidOrOverlay, LitterSprite})

	ISBaseTimedAction.perform(self);
end

function LSDebugLitter:complete()
	return true
end

function LSDebugLitter:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 150
end

function LSDebugLitter:new(character, litter, spriteName)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
	o.litter = litter
	o.spriteName = spriteName
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	return o;
end

return LSDebugLitter