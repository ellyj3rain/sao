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

	-- requirements:
	-- x electricity
	-- x plumbing (req water)
	-- improvements:
	-- x hygiene amount 8/8
	-- x activation cooldown 8/8
	-- power efficiency (how much electricity it requires) 5/5
	-- liquid efficiency (how much water and cleaning liquid is used per wash) 5/5
	-- liquid storage (how much cleaning liquid it can store) 5/5
	-- x precision (chance to generate dirt puddles) 5/5
	-- x breakdown chance (will not work again until repaired, generates dirt puddle) 5/5
	-- x fail chance (increase need instead of decreasing, makes character more visually dirty, bad smell moodle and generate dirt puddle) 5/5
	-- x perfume smell (adds good smell moodle and a trickle of happiness) 3/3
	-- x heated (switch from cold shower to hot shower moodle) 1/1
	-- x dry air jets (won't leave character wet) 1/1
	-- x high pressure jets (will also clean worn clothes) 1/1
	-- x self-powered (won't require electricity) 1/1
	-- x moisture absorber (won't require plumbing, still requires cleaning liquid) 1/1

LSIntObjs = LSIntObjs or {}

local function doShowerMoodle(data, player, fail)
	local moodle, opposite = "BathCold", "BathHot"
	if not fail and data["isHeated"] then moodle = "BathHot"; opposite = "BathCold"; end
	LSUtil.addMoodleValue(player:getModData().LSMoodles, moodle, 0.2, opposite, player, true)
end

local function playFailUISound(soundName)
	getSoundManager():playUISound(soundName)
end

local function playSound(object, soundName)
	local emitter = getWorld():getFreeEmitter(object:getX(),object:getY(),object:getZ())
	emitter:playSoundImpl(soundName, false, object)
end

local function doBreakdown(data, object, sqr)
	playSound(object, "Toilet_Flush_Clogged")
	LSHygiene.TF.doDirtPuddle(sqr)
	data['isBroken'] = true
	playFailUISound("Toilet_Clogged_"..tostring(ZombRand(2)+1))
	LSSync.transmit(object)
end

--local function doBreakdownRoll(data, object, sqr)
--	if ZombRand(100)+1 > data['durability'][1] then return false; end
--	doBreakdown(data, object, sqr)
--	return true
--end

local function doFailRoll(data, player, object, sqr)
	if data['neverBreak'] or ZombRand(100)+1 > data['durability'][1] then return false; end
	LSUtil.makeCharWet(player, true)
	LSUtil.changeCharVisualDirt(player, 0.8, 0.6, true)
	doShowerMoodle(data, player, true)
	local moodles = player:getModData().LSMoodles
	if LSUtil.isValidMoodle(moodles, "Nauseous") and moodles['Nauseous'].Value <= 0 then LSUtil.playCharVoice(player, "_Yuck0", 8); end
	LSUtil.addMoodleValue(moodles, "Nauseous", 0.4, "SmellGood", player, true)
	doBreakdown(data, object, sqr)
	LSUtil.reduceHygiene(player:getModData(), player, 70, 100)
	return true
end

local function doPuddleRoll(data, object, sqr)
	if data['neverBreak'] then return; end
	if ZombRand(100)+1 > data['durability'][2] then return; end
	LSHygiene.TF.doDirtPuddle(sqr)
end

local function doHygieneBenefits(data, player)
	if not data['hasDryJet'] then LSUtil.makeCharWet(player, true); end
	LSUtil.changeCharVisualDirt(player, data['efficiencyMult'][2]*-1, data['efficiencyMult'][3]*-1, data['hasHighPressureJet']) -- vals should be negative to clean
	LSUtil.playCharVoice(player, "LikeHMM0", 3)
	doShowerMoodle(data, player, false)
	if data["isPerfumed"] then -- level - 0.2, 0.4, 0.6; buff - 10, 25, 40
		local moodles = player:getModData().LSMoodles
		if LSUtil.isValidMoodle(moodles, "SmellGood") and moodles['SmellGood'].Value <= 0 then LSUtil.playCharVoice(player, "LikeHMM0", 3); end
		LSUtil.addMoodleValue(moodles, "SmellGood", data["isPerfumed"].level, "Nauseous", player, true)
		LSUtil.changeCharacterMood(player, "Unhappiness", -data["isPerfumed"].buff, true, false, true)
	end
	LSUtil.addHygiene(player:getModData(), player, data["efficiencyMult"][1], data["hygieneMax"]) -- hygieneNeed of 0 = completely satisfied; 30 == shower. e.g. hygieneMax of 30 with hygieneVal of 70
end

local function getNewFog(oldFog, tileSqr)
	local newSprite = "LS_Fog_" .. tostring(ZombRand(8))
	if oldFog then tileSqr:RemoveTileObject(oldFog); end
	local fog = IsoObject.new(getCell(), tileSqr, newSprite)
	fog:setAlpha(0.1)
	tileSqr:AddSpecialObject(fog)
	return fog
end

local event_cache = {}

LSIntObjs.Hygienator = function(player, object)
	if not LSUtil.isValidObj(object, "Hygienator") or not LSUtil.isObjClosePrecise(object, player, 0.5) then return; end
	if not LSUtil.isObjOnSqr(object) then object:setOverlaySprite(nil); return; end
	if LSUtil.isCharBusy(player) or player:isInvisible() then return; end
	local data = InventionsMenu.updateInvData(object)
	if not data then return; end
	local invData = data['inventionData']
	if not invData or not invData['enabled'] or invData['isBroken'] or (not invData['noCooldown'] and LSUtil.isCooldown(invData)) then return; end
	local sqr = object:getSquare()
	if not LSInv.InvHasWater(object, invData) or (not LSUtil.sqrHasEnergy(sqr) and not invData['selfPowered']) then return; end

	if not invData['noCooldown'] then LSUtil.doInvCooldown(object, invData); end

	local id = tostring(object:getX()).."-"..tostring(object:getY())
	if event_cache[id] and event_cache[id].obj and event_cache[id].obj:isExistInTheWorld() then return; end
	event_cache[id] = {
		obj = object,
		data = object:getModData().movableData['inventionData'],
		waterObj = getNewFog(nil, object:getSquare()),
	}
	local count, jetSound, jetSprite = 0, false, false
	--local objOverlaySprite
	--if object:getOverlaySprite() then objOverlaySprite = object:getOverlaySprite():getName(); end

	local waitABit
	waitABit = function()
		if not jetSound then playSound(event_cache[id].obj, "Steam_FIZZ1"); jetSound = true; end
		if count == 0 or math.floor(count)%3 == 0 then event_cache[id].waterObj:setOverlaySprite("LS_Fog_" .. tostring(ZombRand(8)),1,1,1,0.6,false); end
		count = count + (getGameTime():getGameWorldSecondsSinceLastUpdate()*GTLSCheck)
		if count > 6 then
			Events.OnTick.Remove(waitABit)
			--event_cache[id].obj:setOverlaySprite(objOverlaySprite)
			event_cache[id].obj:getSquare():RemoveTileObject(event_cache[id].waterObj)
			if not doFailRoll(event_cache[id].data, player, event_cache[id].obj, sqr) then
				LSSync.transmit(event_cache[id].obj)
				doHygieneBenefits(event_cache[id].data, player)
				doPuddleRoll(event_cache[id].data, event_cache[id].obj, sqr)
			end
			event_cache[id] = nil
			--if not doBreakdownRoll(event_cache[id].data, event_cache[id].obj, sqr) then doPuddleRoll(event_cache[id].data, event_cache[id].obj, sqr); end
		end
	end
	
	Events.OnTick.Add(waitABit)

	if not invData['noPlumbing'] then LSUtil.useObjFluid(object,invData['waterUsage'][1]); end -- b42

end

InventionsMenu = InventionsMenu or {}

InventionsMenu.Hygienator = function(context, parentMenu, character, obj, data, spriteName) --!

end