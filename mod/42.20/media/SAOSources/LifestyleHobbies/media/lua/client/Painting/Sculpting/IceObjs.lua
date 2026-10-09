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

local function playMeltingSound(object)
	local meltEmitter = getWorld():getFreeEmitter(object:getX(),object:getY(),object:getZ())
	meltEmitter:playSoundImpl("Toilet_Flush_Clogged", false, object)
end

local function doMeltSculpture(object)
	playMeltingSound(object)
	local sqr = object:getSquare()
	--if not isClient() then sqr:transmitRemoveItemFromSquare(object); end
	--sqr:RemoveTileObject(obj)
	if isClient() then
		sendClientCommand("LS", "RemoveObject", {object:getX(),object:getY(),object:getZ(),object:getSprite():getName()})
	else
		sqr:transmitRemoveItemFromSquare(object)
		sqr:RemoveTileObject(obj)
	end
	LSHygiene.TF.doDirtPuddle(object)
end

local function doMeltWork(object, data)
	playMeltingSound(object)

	data.style = false
	data.meltStartTime = false
	if isClient() then
		sendClientCommand("LS", "ModifyOverlaySprite", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, "LS_HScraps_DirtPuddle_0"})
		sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, false, data})
	else
		object:setOverlaySprite("LS_HScraps_DirtPuddle_0", isClient()) --get puddle sprite
	end
end

local function getMeltRate(square)
	if not square then return 1; end
	local climate = getClimateManager():getAirTemperatureForSquare(square) or 20
	local temp = 2
	if climate < 0 then temp = 0; elseif climate < 10 then temp = 0.5; elseif climate < 30 then temp = 1; end
	return temp
end

LSIntObjs.StationWork = function(player, object)
	-- set style to false once it becomes a puddle to disable the work option
	local data = object:getModData()
	if (not data.style) or (data.style ~= "Ice") then
		if data.meltStartTime then
			data.meltStartTime = false;
			if isClient() then sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, false, data}); end
		end
		return
	end
	if not data.meltStartTime then -- about 6 real hours at room temperature, 12 at 0 - 10, only 3 at 30+
		data.meltStartTime = 24000
		if isClient() then sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, false, data}); end
		return
	end
	local meltRate = getMeltRate(object:getSquare())
	data.meltStartTime = data.meltStartTime - meltRate
	if data.meltStartTime <= 0 then
		doMeltWork(object, data)
	elseif isClient() then
		if not data['totalMeltPoints'] then data['totalMeltPoints'] = meltRate; return; end
		data['totalMeltPoints'] = data['totalMeltPoints']+meltRate
		if data['totalMeltPoints'] > 20 then
			data['totalMeltPoints'] = 0		
			sendClientCommand("LS", "ModifyObjData", {{object:getX(),object:getY(),object:getZ(),object:getSprite():getName()}, false, data})
		end
	end
end

LSIntObjs.SculptureIce = function(player, object)
	object:getModData().movableData = object:getModData().movableData or {}
	local movData = object:getModData().movableData
	if not movData['meltStartTime'] then movData['meltStartTime'] = 24000; LSSync.transmit(object); return; end -- about 6 real hours at room temperature, 12 at 0 - 10, only 3 at 30+
	local meltRate = getMeltRate(object:getSquare())
	movData['meltStartTime'] = movData['meltStartTime'] - meltRate
	if movData['meltStartTime'] <= 0 then
		movData['meltStartTime'] = false
		LSSync.transmit(object)
		doMeltSculpture(object)
	elseif isClient() then
		if not movData['totalMeltPoints'] then movData['totalMeltPoints'] = meltRate; return; end
		movData['totalMeltPoints'] = movData['totalMeltPoints']+meltRate
		if movData['totalMeltPoints'] > 20 then
			movData['totalMeltPoints'] = 0
			LSSync.transmit(object)
		end
	end
end