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

local function isLumberjackValid(ambt)
	if ambt and ambt['LSLumberjack'] and ambt['LSLumberjack'].isActive then return true; end
	return false
end

local function isLumberjackAmbt(ambt)
	if ambt and ambt['LSLumberjack'] and ambt['LSLumberjack'].completed then return true; end
	return false
end

local ogActionPerform = ISChopTreeAction.perform;
function ISChopTreeAction:perform()
	--print("ISChopTreeAction - perform")
	self.character:setVariable("LSChopSpeed", "End")
	if isLumberjackValid(self.ambt) then
		--print("ISChopTreeAction - is lumberjack")
		if self.ambt['LSLumberjack'].completed then
			--print("ISChopTreeAction - completed")
			local logs = ZombRand(2)+1
			if isClient() then
				sendClientCommand(self.character, "LS", "AddWorldItem", {"Base.Log", logs, false, false, 0, self.treeX, self.treeY, self.treeZ})
			elseif self.treeSqr then
				for n=1,logs do
					self.treeSqr:AddWorldInventoryItem("Base.Log", ZombRandFloat(0.0, 1.0), ZombRandFloat(0.0, 1.0), 0)
				end
			end
		else
			--print("ISChopTreeAction - not completed")
			self.ambt['LSLumberjack'].goal1progress = math.floor(self.ambt['LSLumberjack'].goal1progress+1)
		end
	end
    ogActionPerform(self);
end

local ogActionStart = ISChopTreeAction.start;
function ISChopTreeAction:start()
	self.treeX, self.treeY, self.treeZ = self.tree:getX(), self.tree:getY(), self.tree:getZ()
	self.treeSqr = self.tree:getSquare()
	self.ambt = self.character:getModData().Ambitions
	if isLumberjackAmbt(self.ambt) and self.ambt['LSLumberjack'].isActive then
		local chopSpeed = self.character:getVariableFloat("ChopTreeSpeed", 0)
		chopSpeed = chopSpeed+(chopSpeed/3)
		chopSpeed = tonumber(string.format("%.2f", chopSpeed))
		if chopSpeed == 0 then chopSpeed = 1.5; end
		self.character:setVariable("LSCTS", chopSpeed)
		self.character:setVariable("LSChopSpeed", "Execute")
	end
	ogActionStart(self)
end

local ogActionStop = ISChopTreeAction.stop;
function ISChopTreeAction:stop()
	--print("ISChopTreeAction - stop")
	if not isServer() and self.tree:getObjectIndex() == -1 and isLumberjackValid(self.ambt) then
		--print("ISChopTreeAction - tree chopped")
		if not self.ambt['LSLumberjack'].completed then
			--print("ISChopTreeAction - not completed")
			self.ambt['LSLumberjack'].goal1progress = math.floor(self.ambt['LSLumberjack'].goal1progress+1)
		else
			--print("ISChopTreeAction - spawning logs")
			local logs = ZombRand(2)+1
			if isClient() then
				sendClientCommand(self.character, "LS", "AddWorldItem", {"Base.Log", logs, false, false, 0, self.treeX, self.treeY, self.treeZ})
			elseif self.treeSqr then
				for n=1,logs do
					self.treeSqr:AddWorldInventoryItem("Base.Log", ZombRandFloat(0.0, 1.0), ZombRandFloat(0.0, 1.0), 0)
				end
			end
		end
	end
	self.character:setVariable("LSChopSpeed", "End")
	ogActionStop(self)
end

local ogActionUseEndurance = ISChopTreeAction.useEndurance;
function ISChopTreeAction:useEndurance()
	if not isLumberjackAmbt(self.ambt) or ZombRand(50) < 20 then ogActionUseEndurance(self); end
end

local ogActionUpdate = ISChopTreeAction.update;
function ISChopTreeAction:update()
	if not isLumberjackAmbt(self.ambt) then ogActionUpdate(self);
	else
		self.axe:setJobDelta(self:getJobDelta())
		self.character:faceThisObject(self.tree)
		if instanceof(self.character, "IsoPlayer") then
			self.character:setMetabolicTarget(Metabolics.MediumWork);
		end
	end
end

local ogActionAnimEvent = ISChopTreeAction.animEvent;
function ISChopTreeAction:animEvent(event, parameter)
	local ambt = self.character:getModData().Ambitions
	if not isLumberjackAmbt(ambt) then ogActionAnimEvent(self, event, parameter);
	elseif not isClient() then
		if event == 'ChopTree' and self.axe then
			self.tree:WeaponHit(self.character, self.axe)
			local modifier = 0.5
			if (self.character:getDescriptor():isCharacterProfession(CharacterProfession.LUMBERJACK)) then modifier = 0.2; end
            self.character:addCombatMuscleStrain(self.axe, 1, modifier)
			self:useEndurance()
			if self.tree:getObjectIndex() == -1 then
				if isServer() then
					self.netAction:forceComplete()
				else
					self:forceComplete()
				end
			end
		end
	elseif event == 'ChopTree' then
		self.tree:WeaponHitEffects(self.character, self.axe)
	end
end