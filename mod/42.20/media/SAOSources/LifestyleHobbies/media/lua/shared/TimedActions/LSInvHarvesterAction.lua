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

LSInvHarvesterAction = ISBaseTimedAction:derive("LSInvHarvesterAction");

function LSInvHarvesterAction:isValid()
	return true
end

function LSInvHarvesterAction:waitToStart()
	self.action:setUseProgressBar(false)
	return false
end

local function stopSound(character, sound)
	if sound and sound ~= 0 and character:getEmitter():isPlaying(sound) then
		character:getEmitter():stopSound(sound)
	end
end

function LSInvHarvesterAction:update()
	if self.character:isSitOnGround() or self.character:getVehicle() then self:forceStop(); end

	self.deltaAdd = getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck
	self.fakeDelta = self.fakeDelta+self.deltaAdd
	self.jobProgress = self.fakeDelta
	
	for _, phase in ipairs(self.phases) do
		if not self.phaseStates[phase.name] and self.jobProgress > (self.fakeMax * phase.threshold) then
			self.phaseStates[phase.name] = true
			self[phase.handler](self)
			break
		--elseif self.phaseStates[phase.name] and self.jobProgress < (self.maxTime * phase.threshold) then
			--self.phaseStates[phase.name] = false
		end
	end
	
	self.character:setMetabolicTarget(Metabolics[self.exerciseMetabolics])
end

function LSInvHarvesterAction:gadgetStartSound()
	if self.gadgetStart then return; end
	self:setOverrideHandModels(self.item, self.item)
	self.character:getEmitter():playSound("Gadget_START")
	self.gadgetStart = true
end

function LSInvHarvesterAction:vaccuumStartSound()
	if self.vaccuumStart then return; end
	self.startSound = LSUtil.playSoundCharacter(self.character, "Vaccuum_START", nil, nil, true, nil, {self.volume,false},self.noise)
	self.vaccuumStart = true
end

function LSInvHarvesterAction:endAction()
	stopSound(self.character, self.sound)
	self.character:getEmitter():playSound("Vaccuum_STOP")
	self:forceComplete()
end

local function adjustTime(tA)
	if tA.adjustTime then return; end
	local harvestTime = math.max(0.05,math.min(0.5,0.05/tA.data['power'][1]))
	for n=1,#tA.phases do
		if tA.phases[n].name == "d" then
			tA.phases[n].threshold = harvestTime
		elseif tA.phases[n].name == "e" then
			tA.phases[n].threshold = harvestTime+0.05
		end
	end
	tA.adjustTime = true
end

local function isValidAction(tA)
	return tA.item and not tA.item:isBroken() and not LSUtil.inventionIsEmpty(tA.data) and not LSUtil.isCooldown(tA.data)
end

function LSInvHarvesterAction:harvestReturn()
	--stopSound(self.character, self.sound)
	self.loopCount = self.loopCount+1
	if self.loopCount <= self.loopsGoal then
		self.fakeDelta = 0 -- instead of self:resetJobDelta()
		self.jobProgress = 0
		self:resetPhases({d=true},false) -- {a=true,b=true,...}, all phases
		adjustTime(self)
		if self.loopCount < #self.plantsData then self["harvestValidPlant"](self); end
		LSUtil.rollBreakdownChanceInventionItem(self.character, self.item, self.data, 'Harvester')
		if not isValidAction(self) then self:forceStop(); end
	else
		self.character:getEmitter():playSound("Gadget_STOP")
	end
end

function LSInvHarvesterAction:resetPhases(list, all)
	for _, phase in pairs(self.phases) do
		if self.phaseStates[phase.name] and (all or (list and list[phase.name])) then
			self.phaseStates[phase.name] = false
		end
	end
end

function LSInvHarvesterAction:doInteraction()	
	if self.sound and self.sound == 0 then
		self.sound = LSUtil.playSoundCharacter(self.character, "Vaccuum_LOOP", nil, nil, true, nil, {self.volume,false},nil)
		self:setActionAnim("Bob_Vaccuum_M")
	end
end

local function getLoopsGoal(t)
	if type(t) ~= "table" or #t == 0 then return false; end
	local bonus, threshold = 0, {{22,8},{15,5},{10,3},{6,2}}
	for n=1, #threshold do
		if #t >= threshold[n][1] then bonus = threshold[n][2]; break; end
	end
	return #t-bonus
end

function LSInvHarvesterAction:start()

	self.fakeMax = 550
	self.fakeDelta = 0
	self.deltaAdd = 0
	self.ogFuel = self.data['fuelUses']
	
	-- Get Plants
	self.plantsData = LSUtil.getValidPlants(self.character, self.data['sensors'][1], self.data['sensors'][2]) -- {plants, harvested}
	if not self.plantsData or #self.plantsData == 0 then self:forceStop(); end
	-- More loops the more plants there are
	self.loopsGoal = getLoopsGoal(self.plantsData)
	if not self.loopsGoal then self:forceStop(); end
	--self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Bob_Vaccuum_M")
	self.character:getEmitter():playSound("PutItemInBag")
	
	local harvestTime = math.max(0.05, math.min(0.5,0.10+0.05/self.data['power'][1]))
	local endTime = harvestTime+0.05
	
	self.phases = {
		{name="a",threshold=0.02,handler="gadgetStartSound"},
		{name="b",threshold=0.05,handler="vaccuumStartSound"},
		{name="c",threshold=0.10,handler="doInteraction"}, -- loop sound and anim
		{name="d",threshold=harvestTime,handler="harvestReturn"}, -- harvest plant, resets d and returns to start until goal is reached (then executes final interaction)
		{name="e",threshold=endTime,handler="endAction"}, -- perform action
	}
	
	if self.data['silent'] then self.noise = false; self.volume = 0.2; end
	
end

function LSInvHarvesterAction:stop()
	stopSound(self.character, self.startSound)
	stopSound(self.character, self.sound)
	if self.vaccuumStart then self.character:getEmitter():playSound("Vaccuum_STOP"); end
	
	if self.ogFuel < self.data['fuelUses'] and self.item and not self.item:isBroken() and not LSUtil.isCooldown(tA.data) then LSSync.transmit(self.item); end
	
    ISBaseTimedAction.stop(self);		
end

function LSInvHarvesterAction:useFuel()
	LSUtil.useInventionItem(self.item, self.data)
end

function LSInvHarvesterAction:harvestValidPlant()
	--if #self.plantsData <= self.loopsGoal then return; end
	local hasPlants
	for n=1,#self.plantsData do
		if not self.plantsData[n][2] and self.plantsData[n][1] then
			local plantNum = n
			if n ~= #self.plantsData then
				local randomData = ZombRand(n,#self.plantsData+1)
				if not self.plantsData[randomData][2] and self.plantsData[randomData][1] then
					plantNum = randomData
				end
			end
			local plant = self.plantsData[plantNum][1]
			plant:updateFromIsoObject()
			local plantObj = plant.getObject and plant:getObject()
			if plantObj and plant:canHarvest() then
				self.character:faceThisObject(plantObj)
				local sqr = plant:getSquare()
				local args = {x=sqr:getX(),y=sqr:getY(),z=sqr:getZ()}
				CFarmingSystem.instance:sendCommand(self.character, 'harvest', args)
				--CFarmingSystem.instance:gainXp(self.character, plant)
				self["useFuel"](self) -- reduce fuel
				LSUtil.playSoundCharacter(self.character, "Suction_Pull", nil, nil, true, nil, {self.volume, (ZombRand(10)+1)*0.1+0.5},self.noise)
				self.character:getEmitter():playSound("Suction_Pull")
			end
			self.plantsData[plantNum][2] = true
			hasPlants = true
			break
		end
	end
	if not isValidAction(self) or not hasPlants then self:forceStop(); end -- no fuel or in case something goes wrong (eg. another player harvests remaining plants)
end

function LSInvHarvesterAction:harvestRemainingPlants()
	for n=1,#self.plantsData do
		if not self.plantsData[n][2] and self.plantsData[n][1] then			
			local plant = self.plantsData[n][1]
			plant:updateFromIsoObject()
			if plant:getObject() and plant:canHarvest() then
				local sqr = plant:getSquare()
				local args = {x=sqr:getX(),y=sqr:getY(),z=sqr:getZ()}
				CFarmingSystem.instance:sendCommand(self.character, 'harvest', args)
				--CFarmingSystem.instance:gainXp(self.character, plant)
				self["useFuel"](self) -- reduce fuel
			end
		end
	end
	self.character:getEmitter():playSound("Suction_Pull")
end

function LSInvHarvesterAction:perform()
	stopSound(self.character, self.sound)

	self["harvestRemainingPlants"](self) -- harvest any remaining plants

	LSSync.transmit(self.item)

	self.character:getEmitter():playSound("UI_CleanObject_Perform")

	ISBaseTimedAction.perform(self);
end

function LSInvHarvesterAction:complete()
	return true
end

function LSInvHarvesterAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return -1
end

function LSInvHarvesterAction:new(character, item, itemData)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.item = item
	o.itemData = itemData
	o.data = o.itemData['inventionData']
	--o.loopsGoal = getLoopsGoal(Plants)
	o.ignoreDynamicTime = true
    o.stopOnWalk        = true
    o.stopOnRun         = true
	o.stopOnAim         = true
	o.maxTime = o:getDuration()
	o.jobProgress = 0
	o.phaseStates = {}
	o.loopCount = 0
	o.sound = 0
	o.noise = {50, 30}
	--o.gadgetStart = false
	--o.vaccuumStart = false
	o.exerciseMetabolics = "UsingTools"
	return o;
end