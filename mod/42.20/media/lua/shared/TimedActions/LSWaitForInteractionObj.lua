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

require "TimedActions/ISBaseTimedAction"

LSWaitForInteractionObj = ISBaseTimedAction:derive("LSWaitForInteractionObj")

function LSWaitForInteractionObj:waitToStart()
	self.character:faceThisObject(self.obj)
	return self.character:shouldBeTurning()
end

function LSWaitForInteractionObj:isValid()
	return true
end

function LSWaitForInteractionObj:update()

	self.character:nullifyAiming()
	if self.charData.LSInteractionState == "none" then
		self:forceStop()
	elseif self.charData.LSInteractionState == "doAction" then
		self:forceComplete()
	elseif (self.character:pressedMovement(true)) and (isKeyDown(Keyboard.KEY_LSHIFT)) then
		self:forceStop()
	end

end

function LSWaitForInteractionObj:start()

	--local TargetID = otherPlayer:getOnlineID()
	--local PlayerName = tostring(thisPlayer:getUsername())

	----print("SKCM sending InteractionStart command")
	--sendClientCommand(thisPlayer, "LS", "InteractionStart", {TargetID, PlayerName, "TimedActions/LSSKAction", startImmediately, skill})

	self.charData = self.character:getModData()
	self.charData.LSInteractionState = "waiting"

	self:setOverrideHandModels(nil, nil)

	self.character:setBlockMovement(true)

	local sound = LSMPS.getRandomVoxSound("base_interactions", "Hey", false, self.character:isFemale())
	if sound then
		self.gameSound = self.character:getEmitter():playSound(sound)
		addSound(self.character,self.character:getX(),self.character:getY(),self.character:getZ(),(self.character:isOutside() and 12) or 8,6)
	end

	self:setActionAnim("Bob_Waving")

end

function LSWaitForInteractionObj:serverStart()
	local target_id = self.otherPlayer and self.otherPlayer:getOnlineID()
    local target = target_id and getPlayerByOnlineID(target_id)
	local sourceName = self.character:getUsername()
	if target then
		if self.srvrArg then
			local key = self.srvrArg[1]
			self.args[key] = LSMPS[self.srvrArg[2]](self)
		end
		sendServerCommand(target, "LS", "WasAskedToInteractObj", {target_id, sourceName, self.posArgs, self.interaction, self.args})
		if self.srvrArg then
			sendServerCommand(self.character, "LS", "LSObjInteractionArgsResolved", {self.character:getOnlineID(), self.args})
		end
	end
end

function LSWaitForInteractionObj:stop()

	self.character:setBlockMovement(false)

	if self.charData then
		if self.charData.LSInteractionState == "waiting" then sendClientCommand(self.character, "LS", "StopOrStartInteraction", {self.otherPlayer:getOnlineID(), "sourceStoppedWaiting"}); end
		self.charData.LSInteractionState = "none"
	end

	if self.gameSound and self.gameSound ~= 0 and self.character:getEmitter():isPlaying(self.gameSound) then self.character:getEmitter():stopSound(self.gameSound); end

    ISBaseTimedAction.stop(self);
end

function LSWaitForInteractionObj:perform()

	if self.charData.LSInteractionState == "waiting" then
		--print("TA-LSWaitForInteractionObj waited too much")
		self.charData.LSInteractionState = "none"
		self.character:setBlockMovement(false)
	elseif self.charData.LSInteractionState == "doAction" then
		local resolvedArgs = self.character:getModData().LSObjInteractionArgsPending or self.args
		self.character:getModData().LSObjInteractionArgsPending = nil
		StartInteractionSource(self.character, self.otherPlayer, self.interaction, {resolvedArgs, true})
	end

	ISBaseTimedAction.perform(self);
end

function LSWaitForInteractionObj:complete()

	return true
end

function LSWaitForInteractionObj:getDuration()
	return 600
end

function LSWaitForInteractionObj:new(character, otherPlayer, obj, posArgs, interaction, args, srvrArg)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.character = character
	o.otherPlayer = otherPlayer
	o.obj = obj
	o.posArgs = posArgs
	o.interaction = interaction
	o.args = args
	o.stopOnAim = false
	o.stopOnWalk = false
	o.stopOnRun = true
	o.gameSound = 0
	o.maxTime = o:getDuration()
	o.ignoreDynamicTime = true
	o.useProgressBar = false
	return o;
end

return LSWaitForInteractionObj