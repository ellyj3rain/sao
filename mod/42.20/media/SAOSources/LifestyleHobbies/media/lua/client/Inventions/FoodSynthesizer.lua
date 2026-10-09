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

local event_cache = {}

local function playerIsClose(player, x, y)
	if player and (player:getX() >= x - 30 and player:getX() <= x + 30 and
	player:getY() >= y - 30 and player:getY() <= y + 30) then return true; end
	return false
end

local function validObjConditions(obj)
	return LSUtil.isValidObj(obj, "FoodSynthesizer") and LSUtil.isObjOnSqr(obj) and obj:isExistInTheWorld() and (LSInv.isSelfPowered(obj) or LSUtil.sqrHasEnergy(obj:getSquare()))
end

local FS_count = 0
local FS_eventStart
local FS_evenDelay
local function FS_soundAmbience()
	if not FS_evenDelay then FS_evenDelay = 5/GTLSCheck; end
	FS_count = FS_count + getGameTime():getGameWorldSecondsSinceLastUpdate()
	if FS_count < FS_evenDelay then return; end
	FS_count = 0
	for k, v in pairs(event_cache) do
		if v then
			if not validObjConditions(v.obj) or not playerIsClose(getPlayer(), v.x, v.y) or v.x ~= v.obj:getX() or v.y ~= v.obj:getY() then
				if v.emitter then v.emitter:stopSoundByName(v.soundName); end
				event_cache[k] = nil
			else
				local data = v.obj:getModData()
				local invData = data and data.movableData and data.movableData['inventionData']
				if not invData or not invData['running'] or not invData['enabled'] or invData['isBroken'] then
					if v.emitter then
						v.emitter:stopSoundByName(v.soundName)
						local endSound = (invData['isBroken'] and "MACHINE_BREAK") or "MACHINE_DING"
						v.emitter:playSoundImpl(endSound, false, v.obj)
					end
					event_cache[k] = nil
				elseif invData['running'] and (not v.sound or not v.emitter or not v.emitter:isPlaying(v.sound)) then
					if not v.emitter then v.emitter = getWorld():getFreeEmitter(v.x, v.y, v.z); end -- attempting to use getFreeEmitter outside this range will cause unpredictable behavior
					v.sound = v.emitter:playSoundImpl(v.soundName, false, v.obj)
					v.emitter:playSoundImpl("MACHINE_ON", false, v.obj)
				end
			end
		end
	end
end

local function getFoodVar(mult, burger)
	local food = (burger and "Lifestyle.PasteBurger") or "Lifestyle.PasteGrub"
	local amount = 1
	if mult then
		local rdm = ZombRand(100)+1
		if rdm <= 50 then
			amount = amount+1
			if rdm <= 15 then
				amount = amount+1
				if rdm == 1 then amount = amount+1; end
			end
		end
	end
	return {amount, food}
end

LSIntObjs.FoodSynthesizer = function(character, object)
	if not validObjConditions(object) then return; end
	local data = InventionsMenu.updateInvData(object)
	if not data then return; end
	local invData = data['inventionData']
	if not invData or not invData['enabled'] or invData['isBroken'] or not invData['running'] or not invData['foodTime'] then return; end
	if invData['foodTime'] < getGameTime():getMinutesStamp() then
			invData['running'] = false
			invData['foodTime'] = false
			invData['foodReady'] = getFoodVar(invData['multiplyPaste'],invData['burgerPrint'])
			local failState = LSInv.rollBreakObj(character, object, invData, "FoodSynthesizer")
			local overlay		
			local spriteName = LSUtil.getObjSpriteName(object)			
			if not failState or failState ~= "crit" then
				local outcome = (failState and "bad") or "good"
				overlay = LSInv.getSynthesizerOverlay(spriteName,outcome)
				LSUtil.playSoundCharacter(character, "BEEP_long", nil, nil, nil, object, nil, nil)
				LSInv.doCooldown(object, invData, nil)
				LSSync.transmit(object)
			end
			sendClientCommand("LS", "ModifyOverlaySprite", {{object:getX(),object:getY(),object:getZ(),spriteName}, overlay})
		return
	end
	local objX, objY, objZ = object:getX(), object:getY(), object:getZ()
	local id = tostring(objX).."-"..tostring(objY).."-"..tostring(objZ)
	if event_cache[id] then return; end
	event_cache[id] = {
		obj = object,
		x = objX,
		y = objY,
		z = objZ,
		soundName = "MACHINE_LOOP",
	}
	if not FS_eventStart then FS_eventStart = true; Events.OnTick.Add(FS_soundAmbience); end	
end

local function getFoodTooltipDesc(food, invData, pizzaIcon)
	local rottenIcon = LSUtil.getTexIcon("DeadMouseSkinned")
	local metalIcon = LSUtil.getTexIcon("CanPipe")
	
	local untilMax = LSUtil.round(invData['foodContainer']-invData['storedWeight'],2)
	local capacityText = (untilMax == 0 and "AtCapacity") or (untilMax == invData['foodContainer'] and "Empty") or "ToCapacity"
	local foodDesc = getText("Tooltip_InvFoodSynthesizer_MaxCapacity",invData['foodContainer']).." "..getText("Tooltip_InvFoodSynthesizer_"..capacityText,untilMax).." <LINE>"..
	"<RGB:1,0.8,0.8>"..getText("Tooltip_InvFoodSynthesizer_ExcessWarn").." <TEXT><LINE>"..
	getText("Tooltip_InvFoodSynthesizer_FoodUsage",invData['foodUsage']).." <TEXT><LINE><LINE>"

	local foodText = (food and food:size() > 0 and "<RGB:0.2,1,0.2>"..getText("Tooltip_InvFoodSynthesizer_PlayerHasFood")) or "<RGB:1,0.2,0.2>"..getText("Tooltip_InvFoodSynthesizer_PlayerNotHasFood")
	foodDesc = foodDesc..pizzaIcon.." "..foodText.." <TEXT><LINE><LINE>"

	local rottenText = (invData['acceptRotten'] and "<RGB:0.8,1,0.8>"..getText("Tooltip_InvFoodSynthesizer_FoodRotten")) or "<RGB:1,0.8,0.8>"..getText("Tooltip_InvFoodSynthesizer_FoodNotRotten")
	foodDesc = foodDesc..rottenIcon.." "..rottenText.." <TEXT><LINE><LINE>"
	
	foodDesc = foodDesc..metalIcon.." ".."<RGB:1,0.8,0.8>"..getText("Tooltip_InvFoodSynthesizer_FoodMetal")
	
	return foodDesc
end

InventionsMenu = InventionsMenu or {}

InventionsMenu.FoodSynthesizer = function(context, parentMenu, character, obj, data, spriteName)
	local invData = data['inventionData']
	if not invData or not invData['enabled'] or invData['running'] then return; end
	local sqr = obj:getSquare()
	local pasteTexture = LSUtil.getItemTexAndText("PasteGrub","Lifestyle")
	if invData['foodReady'] then -- retrieve paste
		local option = parentMenu:addOption(getText("ContextMenu_InvFoodSynthesizer_Get"),character,InventionsMenu.FSonInteract,obj,spriteName,invData,"getFood")
		option.iconTexture = pasteTexture
		return -- can't add food or run machine if it has paste inside
	end
	if (not invData['noCooldown'] and LSUtil.isCooldown(invData)) or not LSInv.InvHasWater(obj, invData) or
	(not LSUtil.sqrHasEnergy(sqr) and not invData['selfPowered']) then return; end
	--add food stuff
	local food = LSInv.getSynthesizerFoodItems(character:getInventory(), invData['acceptRotten'])
	local title = getText("ContextMenu_InvFoodSynthesizer_Add",tostring(invData['storedWeight']),tostring(invData['foodContainer']))	
	local pizzaTexture = LSUtil.getItemTexAndText("Pizza")
	local foodDesc = getFoodTooltipDesc(food, invData, "<IMAGE:"..pizzaTexture:getName()..",16,16>")
	if invData['storedWeight'] < invData['foodContainer'] then -- add food
		local option = parentMenu:addOption(title,character,InventionsMenu.FSonInteract,obj,spriteName,invData,"addFood")
		local disable = not food or food:size() == 0
		option.notAvailable = disable
		option.toolTip = LSUtil.getNewTooltip(foodDesc, spriteName, title, disable and getText("Tooltip_Interaction_NoItems"))
		option.iconTexture = pizzaTexture
	else
		local option = parentMenu:addOption(title)
		option.toolTip = LSUtil.getNewTooltip(foodDesc, spriteName, title, nil)
		option.iconTexture = pizzaTexture
		option.goodColor = true
	end
	 -- run machine
	local runOption = parentMenu:addOption(getText("ContextMenu_InvFoodSynthesizer_Run",tostring(invData['foodUsage'])),character,InventionsMenu.FSonInteract,obj,spriteName,invData,"run")
	runOption.iconTexture = pasteTexture
	runOption.toolTip = LSUtil.getNewTooltip(foodDesc, spriteName, title, nil)
	runOption.notAvailable = invData['storedWeight'] < invData['foodUsage']
end

InventionsMenu.FSonInteract = function(character, obj, spriteName, invData, command)
	if LSUtil.walkToFront(character, obj) then
		local food = command == "addFood" and invData['storedWeight'] < invData['foodContainer'] and LSInv.getSynthesizerFoodItems(character:getInventory(), invData['acceptRotten'])
		local isValid = (command == "getFood" and invData['foodReady']) or
		(command == "run" and invData['storedWeight'] >= invData['foodUsage']) or
		(food and food:size() > 0)
		if isValid then ISTimedActionQueue.add(LSFoodSynthesizer:new(character, obj, spriteName, invData, command)); end
	end
end
