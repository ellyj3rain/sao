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

require "TimedActions/ISBaseTimedAction"; require "Moveables/ISMoveableTools"; require "Moveables/ISMoveableSpriteProps";

CleanRoomAction = ISBaseTimedAction:derive("CleanRoomAction");

local function GetConsumption(character, bleach)

	local consumption = 0.05
	--if bleach:getFullType() == "Lifestyle.BucketBleachFull" then consumption = 0.03; end
	local skillLevel = character:getPerkLevel(Perks.Cleaning)
	local skillDiv = 1

	local divTable = {
	[10] = 3,
	[8] = 2.4,
	[6] = 1.9,
	[4] = 1.5,
	[2] = 1.2,
	}

	for k, v in pairs(divTable) do
		if skillLevel >= tonumber(k) then skillDiv = v; break; end
	end

	local traitTable = {
	Tidy = 0.7,
	Sloppy = 1.5,
	CleanFreak = 1.8,
	All_Thumbs = 1.2,
	Dextrous = 0.9,
	}

	for k, v in pairs(traitTable) do
		if character:hasTrait(CharacterTrait[string.upper(tostring(k))]) then consumption = consumption*v; break; end
	end

	consumption = consumption/skillDiv

	return consumption
end

local function adjustStats(character, heavy)
	local xpChange = 5

	if heavy then xpChange = 10; end
	
	local skillLevel = math.max(1, character:getPerkLevel(Perks.Cleaning))

	local args = {1,-2,-0.01}
	local traitTable = {
	Tidy = {1,-3,-0.03},
	Sloppy = {0.5,3,0.03},
	CleanFreak = {1,-2,-0.015},
	CouchPotato = {1,2,0.015},
	}

	for k, v in pairs(traitTable) do
		if character:hasTrait(CharacterTrait[string.upper(tostring(k))]) then args = v; break; end
	end

	xpChange = xpChange*args[1]

	LSUtil.changeCharacterMoodGroup(character, {
		["Stress"] = {args[3], args[3] < -0.01 or args[3] > 0, false, true},
		["Boredom"] = {args[2], args[2] > 1, false, true},
	})

	if skillLevel < 10 then
		xpChange = xpChange*skillLevel
		--character:getXp():AddXP(Perks.Cleaning, xpChange)
		sendClientCommand(character, "LS", "AddXP", {"Cleaning", xpChange})
	end

end

function CleanRoomAction:isValid()
	return true
end

function CleanRoomAction:waitToStart()
	self.character:faceLocation(self.square:getX(), self.square:getY())
	return self.character:shouldBeTurning()
end

function CleanRoomAction:update()

	if self.count >= self.countTotal then
		self.count = 0
		local sound
		if self.isHeavy	then
			sound = "Mop_Clean"..tostring(ZombRand(6)+1)
		else
			sound = "Broom_Sweep"..tostring(ZombRand(5)+1)
		end
		self.character:getEmitter():playSound(sound);
	else
		self.count = self.count + getGameTime():getGameWorldSecondsSinceLastUpdate()
	end
	
    self.character:setMetabolicTarget(Metabolics.LightWork)	
end

function CleanRoomAction:start()
	self:setActionAnim("Rake")

	if self.isHeavy then 
		self:setOverrideHandModels("Lifestyle.Mop", nil)
	end
	
	if not self.square:haveBlood() then
		self.character:reportEvent("EventCleanDirt")
	else
		self.character:reportEvent("EventCleanBlood")
	end

	self.countTotal = 8/GTLSCheck--40

end

function CleanRoomAction:stop()
    ISBaseTimedAction.stop(self);
end

local function removeSquareDirt(character, thisSqr, isHeavy, hasGloves)
	if not thisSqr then return false; end
	if isClient() then
		if not isHeavy and hasGloves then
			for i=0,thisSqr:getObjects():size()-1 do
				local object = thisSqr:getObjects():get(i)
				if object then
					local texName = object:getTextureName()
					if texName and luautils.stringStarts(texName, "brokenglass_") and ISMoveableTools.isObjectMoveable(object) then
						sendClientCommand(character, "LS", "RemoveBrokenGlass", {object:getX(), object:getY(), object:getZ()})
						--self.glassToRemove = object
						break
					end
				end
			end
		end
		sendClientCommand("LS", "RemoveDirtTile", {thisSqr:getX(), thisSqr:getY(), thisSqr:getZ(), isHeavy})
		return true
	end
	
	local listDirt = {"overlay_grime","trash&junk","trash_","d_floorleaves","d_trash","LS_Scraps"}
	if hasGloves then table.insert(listDirt,"brokenglass_"); end
	local listBlood = {"overlay_messages","overlay_graffiti","overlay_blood","LS_HScraps","blood_floor"}
	local mustRemove = {}
	local glassObj
	for j=0,thisSqr:getObjects():size()-1 do
		if j < 0 or j > thisSqr:getObjects():size() then break; end
		local object = thisSqr:getObjects():get(j)
		if object then
			local attachedsprite = object:getAttachedAnimSprite()
			local texName = object:getTextureName()
			local spriteName = object:getOverlaySprite() and object:getOverlaySprite():getName()

			if not isHeavy then
				for n=1, #listDirt do
					if texName and listDirt[n] == "brokenglass_" and luautils.stringStarts(texName, listDirt[n]) and ISMoveableTools.isObjectMoveable(object) then
						glassObj = object
						break
					end
					if texName and luautils.stringStarts(texName, listDirt[n]) then table.insert(mustRemove, object); break; end
					if spriteName and luautils.stringStarts(spriteName, listDirt[n]) then object:setOverlaySprite(nil, false); break; end
					if attachedsprite then
						local removed
						for i=0,attachedsprite:size()-1 do
							if i < 0 or i > attachedsprite:size() then break; end
							local sprite = attachedsprite:get(i)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listDirt[n]) then removed = true; object:RemoveAttachedAnim(i); break; end
						end
						if removed then break; end
					end
				end
			else
				for n=1, #listBlood do
					if texName and luautils.stringStarts(texName, listBlood[n]) then table.insert(mustRemove, object); break; end
					if spriteName and luautils.stringStarts(spriteName, listBlood[n]) then object:setOverlaySprite(nil, false); break; end
					if attachedsprite then
						local removed
						for i=0,attachedsprite:size()-1 do
							if i < 0 or i > attachedsprite:size() then break; end
							local sprite = attachedsprite:get(i)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listBlood[n]) then removed = true; object:RemoveAttachedAnim(i); break; end
						end
						if removed then break; end
					end
				end
			end
		end
	end
	if glassObj then ISMoveableTools.isObjectMoveable(glassObj):pickUpMoveable(character, thisSqr, glassObj, true); end
	if #mustRemove > 0 then
		for n=1, #mustRemove do
			thisSqr:RemoveTileObject(mustRemove[n]);
		end
	end
	
	if isHeavy and thisSqr:haveBlood() then thisSqr:removeBlood(false, false); end
	return true
end

local function getCleaningItems(character)
	
	local list = {"Broom","Mop","Broom_Twig"}
	local items = {}
	for n=1, #list do
		local item = LSUtil.getItem(character, false, list[n])
		if item then items[list[n]] = item; end
	end
	items["Broom"] = items["Broom"] or items["Broom_Twig"]
	items["Bleach"] = LSUtil.getItemFluid(character, "Bleach", false, 5, false)
	return items
end

local function getSquareDirt(thisSqr, hasGloves)
	if not thisSqr then return false, false; end
	local listDirt = {"overlay_grime","trash&junk","trash_","d_floorleaves","d_trash","LS_Scraps"}
	if hasGloves then table.insert(listDirt,"brokenglass_"); end
	local listBlood = {"overlay_messages","overlay_graffiti","overlay_blood","LS_HScraps","blood_floor"}
	local blood, dirt = thisSqr:haveBlood(), false
	for j=0,thisSqr:getObjects():size()-1 do
		local object = thisSqr:getObjects():get(j)
		if object then
			local attachedsprite = object:getAttachedAnimSprite()
			local texName = object:getTextureName()
			local spriteName = object:getOverlaySprite() and object:getOverlaySprite():getName()

			if not dirt then
				for n=1, #listDirt do
					if texName and luautils.stringStarts(texName, listDirt[n]) then dirt = true; break; end
					if spriteName and luautils.stringStarts(spriteName, listDirt[n]) then dirt = true; break; end
					if attachedsprite then
						for i=1,attachedsprite:size() do
							local sprite = attachedsprite:get(i-1)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listDirt[n]) then dirt = true; break; end
						end
						if dirt then break; end
					end
				end
			end
			if not blood then
				for n=1, #listBlood do
					if texName and luautils.stringStarts(texName, listBlood[n]) then blood = true; break; end
					if spriteName and luautils.stringStarts(spriteName, listBlood[n]) then blood = true; break; end
					if attachedsprite then
						for i=1,attachedsprite:size() do
							local sprite = attachedsprite:get(i-1)
							local spriteParentName = sprite and sprite:getParentSprite() and sprite:getParentSprite():getName()
							if spriteParentName and luautils.stringStarts(spriteParentName, listBlood[n]) then blood = true; break; end
						end
						if blood then break; end
					end
				end
			end
		end
		if blood and dirt then break; end
	end
	return blood, dirt
end

local function getDirtyTiles(tileSqr, playerSqr, hasGloves)

	local lightList, heavyList = {}, {}

	for x = tileSqr:getX()-4,tileSqr:getX()+4 do
		for y = tileSqr:getY()-4,tileSqr:getY()+4 do
			local thisSqr = getCell():getGridSquare(x,y,playerSqr:getZ())
			if thisSqr and thisSqr ~= tileSqr and thisSqr:isOutside() == playerSqr:isOutside() then
				local blood, dirt = getSquareDirt(thisSqr, hasGloves)
				if blood then table.insert(heavyList, thisSqr); end
				if dirt then table.insert(lightList, thisSqr); end
			end
		end
	end
	return lightList, heavyList
end

function CleanRoomAction:perform()
	if self.isHeavy and self.bleach then
		local consumption = GetConsumption(self.character, self.bleach)
		LSUtil.adjustFluid(self.bleach, consumption, self.character)
	end

	local hasGloves = self.character:getClothingItem_Hands()
	if removeSquareDirt(self.character, self.square, self.isHeavy, hasGloves) and not LSUtil.isCharSitting(self.character, self.character:getModData()) then
		local newItems = getCleaningItems(self.character)
		if newItems["Broom"] or (newItems["Mop"] and newItems["Bleach"]) then
			local lightList, heavyList = getDirtyTiles(self.square, self.character:getSquare(), hasGloves)
			local closestDirt = LSUtil.srqGetClosest(lightList, self.character)
			local closestBlood = LSUtil.srqGetClosest(heavyList, self.character)
			local canCleanLight = closestDirt and newItems["Broom"]
			local canCleanBlood = closestBlood and newItems["Mop"] and newItems["Bleach"]
			local tool, sqr
			if canCleanBlood then tool, sqr = newItems["Mop"], closestBlood; elseif canCleanLight then tool, sqr = newItems["Broom"], closestDirt; end
			if tool then
				local previousAction = self
				if tool:getContainer() ~= self.character:getInventory() then
					local action = ISInventoryTransferAction:new(self.character, tool, tool:getContainer(), self.character:getInventory(), nil)
					ISTimedActionQueue.addAfter(self, action)
					previousAction = action					
				end
				if LSUtil.canEquipItem(self.character, tool, true, true) then
					local equipAction = ISEquipWeaponAction:new(self.character, tool, 50, true, true)
					ISTimedActionQueue.addAfter(previousAction, equipAction)
					previousAction = equipAction		
				end
				if canCleanBlood and newItems["Bleach"]:getContainer() ~= self.character:getInventory() then
					local action = ISInventoryTransferAction:new(self.character, newItems["Bleach"], newItems["Bleach"]:getContainer(), self.character:getInventory(), nil)
					ISTimedActionQueue.addAfter(previousAction, action)
					previousAction = action
				end
				local adjSqr = AdjacentFreeTileFinder.Find(sqr, self.character)
				if adjSqr then
					local duration = LSCleaning.getCleaningTime(self.character, {"Floor", false, canCleanBlood and newItems["Bleach"]})
					local walkAction = ISWalkToTimedAction:new(self.character, adjSqr)
					ISTimedActionQueue.addAfter(previousAction, walkAction)
					ISTimedActionQueue.addAfter(walkAction, CleanRoomAction:new(self.character, tool, newItems, sqr, canCleanBlood, duration))
				end
			end
		end
	end
   
	adjustStats(self.character, self.isHeavy)
 
	ISBaseTimedAction.perform(self);
end

function CleanRoomAction:complete()
	if self.isHeavy and self.square:haveBlood() then self.square:removeBlood(false, false); end
	return true
end

function CleanRoomAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return self.duration
end

function CleanRoomAction:new(character, tool, items, square, isHeavy, duration)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.square = square
	o.tool = tool
	o.items = items
	o.bleach = items["Bleach"]
	o.isHeavy = isHeavy
	o.stopOnWalk = true
	o.stopOnRun = true
	o.stopOnAim = true
	o.duration = duration
	o.maxTime = o:getDuration()
    o.caloriesModifier = 5
	o.count = 0
	return o;
end

--return CleanRoomAction