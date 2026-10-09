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

LSIntObjs = {}

local function checkClockSound(object)
	local movementEmitter = getWorld():getFreeEmitter(object:getX(),object:getY(),object:getZ())
	movementEmitter:playSoundImpl("GFClock_TickTock", false, object)
	if (getGameTime():getHour() ~= 12) and (getGameTime():getHour() ~= 24) and (getGameTime():getHour() ~= 0) then
		if object:getModData().movableData['chime'] then
			object:getModData().movableData['chime'] = false
			if isClient() then
				sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, {['chime']=false}, false})
			end
		end
		return
	end
	if not object:getModData().movableData['chime'] then
		object:getModData().movableData['chime'] = true
		if isClient() then sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, {['chime']=true}, false}); end
		local emitter = getWorld():getFreeEmitter(object:getX(),object:getY(),object:getZ())
		emitter:playSound("GFClock_Chime", object)
		addSound(object, object:getX(), object:getY(), object:getZ(), 30, 10)
	end
end

LSIntObjs.GFClock = function(player, object)
	if not LSUtil.isObjOnSqr(object) then return; end
	object:getModData().movableData = object:getModData().movableData or {}
	if (not object:getModData().movableData['lastWind']) or (not object:getModData().movableData['active']) then return; end
	if (object:getModData().movableData['lastWind']+36 < tonumber(getGameTime():getWorldAgeHours())) then
		object:getModData().movableData['active'] = false
		if isClient() then sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, object:getModData().movableData, false}); end
	else
		checkClockSound(object)
	end
end

local function drinkingBuddyTable(key)
	local t = {
		LS_Inventions_33 = "LS_Inventions_15",
		LS_Inventions_32 = "LS_Inventions_13",
		LS_Inventions_13 = "LS_Inventions_32",
		LS_Inventions_15 = "LS_Inventions_33",
	}
	return t[key]
end

LSIntObjs.DrinkingBuddy = function(player, object)
	local modData = object:getModData()
	--modData.movableData = modData.movableData or {}
	--movData = modData.movableData
	if not modData then return; end
	if not modData['overlay'] then
		local spriteName = object:getSprite():getName()
		modData['overlay'] = (spriteName == "LS_Inventions_12" and "LS_Inventions_32") or "LS_Inventions_33"
		object:setOverlaySprite(modData['overlay'], false)
	end
	modData['timer'] = (modData['timer'] and modData['timer']+1) or 1
	if modData['timer'] > 30 and LSUtil.rdm_inst:random(10) == 10 then
		modData['timer'] = 0
		local spriteName = object:getSprite():getName()
		if spriteName == "LS_Inventions_12" and modData['overlay'] ~= "LS_Inventions_32" and modData['overlay'] ~= "LS_Inventions_13" then modData['overlay'] = "LS_Inventions_32";
		elseif spriteName == "LS_Inventions_14" and modData['overlay'] ~= "LS_Inventions_33" and modData['overlay'] ~= "LS_Inventions_15" then modData['overlay'] = "LS_Inventions_33"; end
		local newOverlay = drinkingBuddyTable(modData['overlay'])
		object:setOverlaySprite(newOverlay, false)
		modData['overlay'] = newOverlay
		local emitter = getWorld():getFreeEmitter(object:getX(),object:getY(),object:getZ())
		emitter:playSound("Squeak_METAL"..tostring(ZombRand(3)+1), object)
	end
end

local function objectIsValid(obj)
	if obj and instanceof(obj, "IsoObject") and obj:getSquare() and obj:getX() and obj:getY() then return true; end
	return false
end

local function sqrHasEnergy(obj)
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	obj:getSquare():haveElectricity()) then
		return false
	end
	return true
end

local function playerIsClose(player, obj)
	if player and (player:getX() >= obj:getX() - 30 and player:getX() <= obj:getX() + 30 and
	player:getY() >= obj:getY() - 30 and player:getY() <= obj:getY() + 30) then return true; end
	return false
end

local function getCustomName(object)
	if not object then return nil; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("CustomName") then
        return properties:get("CustomName")
    end
    return nil
end

local function getGroupName(object)
	if not object then return nil; end
    local properties = object:getSprite() and object:getSprite():getProperties()
    if properties and properties:has("GroupName") then
        return properties:get("GroupName")
    end
    return nil
end

local function getInteractiveObjsCN()
	return {"Sculpture Ice","Sculpture Lamp","Hygienator","FoodSynthesizer","DrinkingBuddy"}
end

local function getInteractiveObjsGN()
	return {"GF Clock","StationWork"}
end

function LSrefreshIO(player)
	local objList = require("Properties/Objects/List")
	if (not objList) or (#objList == 0) then return; end
	for i,v in ipairs(objList) do
		if objectIsValid(v) and playerIsClose(player, v) and LSUtil.isObjOnSqr(v) then
			local groupName = getGroupName(v)
			if groupName then
				local t = getInteractiveObjsGN()
				for n=1, #t do
					if groupName == t[n] then
						local nameWS = groupName:gsub(" ", "")
						if LSIntObjs[nameWS] then LSIntObjs[nameWS](player, v); end
						break
					end
				end
			end
			local customName = getCustomName(v)
			if customName then
				local t = getInteractiveObjsCN()
				for n=1, #t do
					if customName == t[n] then
						local nameWS = customName:gsub(" ", "")
						if LSIntObjs[nameWS] then LSIntObjs[nameWS](player, v); end
						break
					end
				end
			end
		end
	end
end
