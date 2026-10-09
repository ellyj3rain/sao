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

LSIntObjs = LSIntObjs or {}

local function objHasEnergy(obj)
	if not ((SandboxVars.ElecShutModifier > -1 and
	GameTime:getInstance():getNightsSurvived() < SandboxVars.ElecShutModifier) or
	obj:getSquare():haveElectricity()) then
		return false
	end
	return true
end

local function getOnOverlay(lamp)
	--if lamp then print("LSIntObjs.SculptureLamp: OVERLAY IS "..lamp); else print("LSIntObjs.SculptureLamp: NO OVERLAY") end
	local overlays = {
		LS_Sculptures_lighting01_0 = "LS_Sculptures_lighting01_on_0",
		LS_Sculptures_lighting01_1 = "LS_Sculptures_lighting01_on_1",
	}
	return overlays[lamp] or false
end

local function isTurnedOn(object)
	return objHasEnergy(object) and object:hasLightBulb() and object:isActivated()
end

local function updateObjSprite(object, sprite)
	--object:setOverlaySprite(sprite, isClient())
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, sprite})
		sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, false, object:getModData()})
	else
		object:setOverlaySprite(sprite, isClient())
	end
end

LSIntObjs.SculptureLamp = function(player, object)
	local isActive
	--print("LSIntObjs.SculptureLamp: START")
	if instanceof(object, 'IsoLightSwitch') then
		--print("LSIntObjs.SculptureLamp: IS IsoLightSwitch")
		if isTurnedOn(object) then
			--print("LSIntObjs.SculptureLamp: IS isTurnedOn")
			isActive = true
			local lightOverlay = getOnOverlay(object:getSprite():getName())
			if lightOverlay then
				--print("LSIntObjs.SculptureLamp: IS lightOverlay")
				if (not object:getOverlaySprite()) or (object:getOverlaySprite():getName() ~= lightOverlay) then
					--print("LSIntObjs.SculptureLamp: UPDATING")
					updateObjSprite(object, lightOverlay)
				end
			end
		end
	end
	if (not isActive) and object:getOverlaySprite() then
		--print("LSIntObjs.SculptureLamp: REMOVE")
		updateObjSprite(object, nil)
	end
end