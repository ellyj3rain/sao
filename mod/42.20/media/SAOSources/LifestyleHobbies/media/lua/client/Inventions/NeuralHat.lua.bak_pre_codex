-------------------------------------------------------------------------------------------------
--		----	  |			  |			|		 |				|    --    |      ----			--
--		----	  |			  |			|		 |				|    --	   |      ----			--
--		----	  |		-------	   -----|	 ---------		-----          -      ----	   -------
--		----	  |			---			|		 -----		------        --      ----			--
--		----	  |			---			|		 -----		-------	 	 ---      ----			--
--		----	  |		-------	   ----------	 -----		-------		 ---      ----	   -------
--			|	  |		-------			|		 -----		-------		 ---		  |			--
--			|	  |		-------			|	 	 -----		-------		 ---		  |			--
--------------------------------------------------------------------------------------------------

InventionsMenu = InventionsMenu or {}
LS_NeuralHat = {}

LS_NeuralHat.getState = function(character)  -- 0 off 1 on 2 bad 3 overdrive 4 overdrive lvl2 5 overdrive lvl3
	local headgear = character:getWornItems():getItem(ItemBodyLocation.HAT)
	local state
	if headgear and headgear:getType() == "NeuralHat" then
		state = headgear:getVisual():getTextureChoice() or 0
	end
	return state
end

LS_NeuralHat.isActive = function(state)
	return state and state ~= 0
end

LS_NeuralHat.getActive = function(character)
	local state = LS_NeuralHat.getState(character)
	return LS_NeuralHat.isActive(state)
end

LS_NeuralHat.getCompleteInfo = function(character)  -- 0 off 1 on 2 bad 3 overdrive 4 overdrive lvl2 5 overdrive lvl3
	local info = {}
	info.headgear = character:getWornItems():getItem(ItemBodyLocation.HAT)
	if info.headgear and info.headgear:getType() == "NeuralHat" then
		info.state = info.headgear:getVisual():getTextureChoice() or 0
		info.active = LS_NeuralHat.isActive(info.state)
		local itemData = info.headgear:getModData().movableData
		info.data = itemData and itemData['inventionData']
	end
	return info
end

local activateAction = function(item, character, invData, targetState, currentState)
	-- Check conditions again
	if targetState == currentState or currentState == 2 then return; end
	if not LSUtil.isValidInvItem(item) or item:isBroken() or invData['isBroken'] or LSUtil.inventionIsEmpty(invData) or LSUtil.isCooldown(invData) or
	LSUtil.isCharBusy(character) or not character:isEquipped(item) or character:isHandItem(item) then return; end

	ISTimedActionQueue.add(LSInvNeuralHatPress:new(character, item, invData, targetState, currentState))
end

local function doActivateOption(parentMenu, character, item, invData, state)
	local isActive = state ~= 0
	local notEquipped = not character:isEquipped(item) or character:isHandItem(item)
	local empty = LSUtil.inventionIsEmpty(invData)
	local cooldown = LSUtil.isCooldown(invData)
	local endText = (isActive and "Off") or "On"
	local option = parentMenu:addOption(getText("ContextMenu_Jukebox_Turn"..endText), item, activateAction, character, invData, (isActive and 0) or 1, state)
	local disable
	local text = "Tooltip_InvNeuralHat_"..endText
	if notEquipped or empty or cooldown or invData['isBroken'] then
		disable = true
		text = (cooldown and "Tooltip_Inventions_OptionCD") or (empty and "IGUI_Inventions_Stats_noFuel") or "Tooltip_Inventions_NotEquipped"
		if isActive then
			invData['running'] = false
			LSUtil.changeTexture_Item(character, item, 0)
			LSInv.doDataTransmit(item, invData)
		end
	end
	option.notAvailable = disable
	option.toolTip = LSUtil.getSimpleTooltip(getText(text))
	option.iconTexture = getTexture((isActive and 'media/ui/speedControls/Pause_On.png') or 'media/ui/speedControls/FFwd1_Off.png')
	return not disable and isActive and state ~= 2
end

local beforeActivation = function(item, character, invData, targetState, currentState)
	if not invData or invData['fuelUses'] < invData['fuelContainer'][1]/2 then return; end
	activateAction(item, character, invData, targetState, currentState)
end

local function doOverdriveOption(context, parentMenu, character, item, invData, state)
	if not invData['overdrive'][1] then return; end
	--main
	local currentLvl = math.floor(math.max(0, state-2))
	local mainOption = parentMenu:addOption(getText("ContextMenu_InvNeuralHat_Overdrive",currentLvl,invData['overdrive'][1]))
	local delay = invData['recentActive'] and invData['recentActive'] > 0
	local texMain = (delay and 'Wait_On') or 'Wait_Off'
	mainOption.iconTexture = getTexture('media/ui/speedControls/'..texMain..'.png')
	mainOption.notAvailable = delay
	if delay then
		mainOption.toolTip = LSUtil.getSimpleTooltip(getText("Tooltip_InvNeuralHat_Overdrive_Delay"))
		return
	end
	local submenu = parentMenu:getNew(parentMenu)
	context:addSubMenu(mainOption, submenu)

	--turnoff
	local offOption = submenu:addOption(getText("ContextMenu_InvNeuralHat_Overdrive_Off"), item, activateAction, character, invData, 1, state)
	offOption.notAvailable = state < 3
	offOption.iconTexture = getTexture('media/ui/noPower_icon.png')

	-- options
	local halfFuel = invData['fuelUses'] < invData['fuelContainer'][1]/2
	for n=1, invData['overdrive'][1] do
		local newOption = submenu:addOption(tostring(n), item, beforeActivation, character, invData, n, state)
		local disable = state == n or halfFuel
		local texture = (n == 1 and "fire") or "fire"..tostring(n)
		newOption.notAvailable = disable
		if disable then
			local text = (halfFuel and "Tooltip_InvNeuralHat_Overdrive_Half") or "Tooltip_InvNeuralHat_Overdrive_Same"
			newOption.toolTip = LSUtil.getSimpleTooltip(getText(text))
			texture = texture.."No"
		end
		newOption.iconTexture = getTexture('media/ui/'..texture..'_icon.png')
	end
end

InventionsMenu.NeuralHat = function(context, parentMenu, character, item, data, itemType)
	-- Conditions
	if LSUtil.isCharBusy(character) then return; end
	--
	local state = item:getVisual():getTextureChoice()
	-- Activate
	local isValid = doActivateOption(parentMenu, character, item, data['inventionData'], state)
	-- Overdrive Modes
	if isValid then doOverdriveOption(context, parentMenu, character, item, data['inventionData'], state); end
end

local neuralXP_cached

local function cacheXPAdd(character, data, state)
	--LSUtil.debugPrint("LS_NeuralHat.cacheXP, start")
	if neuralXP_cached and neuralXP_cached["delay"] > 0 then neuralXP_cached["delay"] = neuralXP_cached["delay"]-1; return; end
	if not neuralXP_cached then neuralXP_cached = {}; end
	local skillTable
	local char_xp = character:getXp()
	for i=1,Perks.getMaxIndex()-1 do
		local skill = Perks.fromIndex(i)
		local parentID = skill and skill:getParent() and skill:getParent():getId()
		if parentID and parentID ~= "None" then
			local skillID = skill:getId()
			local skillLevel = character:getPerkLevel(Perks[skillID])
			local currentXP = char_xp:getXP(skill)
			--LSUtil.debugPrint("LS_NeuralHat.cacheXP, checking skill "..tostring(skillID))
			if skillLevel < 10 and currentXP > 0 then
				local addXP = 0
				if neuralXP_cached[skillID] and not neuralXP_cached[skillID].synced then neuralXP_cached[skillID].xp = false; end
				if neuralXP_cached[skillID] and neuralXP_cached[skillID].level == skillLevel and neuralXP_cached[skillID].xp and neuralXP_cached[skillID].xp ~= currentXP then
					local diff = currentXP-neuralXP_cached[skillID].xp
					if diff > 0 then
						local mult = data['efficiencyMult'][1]*state
						addXP = (diff*mult)+neuralXP_cached[skillID].residue
						neuralXP_cached[skillID].round = (neuralXP_cached[skillID].round and neuralXP_cached[skillID].round+1) or 1
						if addXP >= 1 or neuralXP_cached[skillID].round >= 2 then -- either 1xp or if its the second round with low gains (we add so the neural hat doesnt feel unresponsive)
							if LSUtil.rdm_inst:random(3) == 1 then addXP=addXP+(addXP*data['efficiencyMult'][3]); end -- extra xp
							if not skillTable then skillTable = {}; end
							table.insert(skillTable, {skillID, addXP, false})
							neuralXP_cached[skillID].xp = currentXP+addXP
							neuralXP_cached[skillID].residue = 0
							neuralXP_cached[skillID].round = 0
							neuralXP_cached[skillID].synced = false
							--LSUtil.debugPrint("LS_NeuralHat.cacheXP, adding xp "..tostring(addXP).." for perk "..tostring(skillID))
						else
							neuralXP_cached[skillID].residue = addXP
							neuralXP_cached[skillID].xp = currentXP
							neuralXP_cached[skillID].synced = true
							--LSUtil.debugPrint("LS_NeuralHat.cacheXP, residue xp "..tostring(addXP).." for perk "..tostring(skillID))
						end
					end
				end
				neuralXP_cached[skillID] = neuralXP_cached[skillID] or {}
				if addXP == 0 or not neuralXP_cached[skillID].xp then neuralXP_cached[skillID].xp = currentXP; neuralXP_cached[skillID].synced = true; end
				neuralXP_cached[skillID].level = skillLevel
				neuralXP_cached[skillID].residue = neuralXP_cached[skillID].residue or 0
			end
		end
	end
	neuralXP_cached["delay"] = 5
	if skillTable then LSUtil.giveXPBatch(character, skillTable); end
end

local function cacheXPRemove(character, dunceVal)
	--LSUtil.debugPrint("LS_NeuralHat.cacheXP, start")
	if neuralXP_cached and neuralXP_cached["delay"] > 0 then neuralXP_cached["delay"] = neuralXP_cached["delay"]-1; return; end
	if not neuralXP_cached then neuralXP_cached = {}; end
	local skillTable
	local char_xp = character:getXp()
	for i=1,Perks.getMaxIndex()-1 do
		local skill = Perks.fromIndex(i)
		local parentID = skill and skill:getParent() and skill:getParent():getId()
		if parentID and parentID ~= "None" then
			local skillID = skill:getId()
			local skillLevel = character:getPerkLevel(Perks[skillID])
			local currentXP = char_xp:getXP(skill)
			--LSUtil.debugPrint("LS_NeuralHat.cacheXP, checking skill "..tostring(skillID))
			if skillLevel < 10 and currentXP > 0 then
				local removeXP = 0
				if neuralXP_cached[skillID] and not neuralXP_cached[skillID].synced then neuralXP_cached[skillID].xp = false; end
				if neuralXP_cached[skillID] and neuralXP_cached[skillID].level == skillLevel and neuralXP_cached[skillID].xp and neuralXP_cached[skillID].xp ~= currentXP then
					local diff = currentXP-neuralXP_cached[skillID].xp
					if diff > 0 and currentXP-diff > 0 then
						local mult = math.min(0.8,dunceVal)
						removeXP = (diff*mult)+neuralXP_cached[skillID].residue
						neuralXP_cached[skillID].round = (neuralXP_cached[skillID].round and neuralXP_cached[skillID].round+1) or 1
						if removeXP >= 1 or neuralXP_cached[skillID].round >= 2 then -- either 1xp or if its the second round with low gains (we remove so the neural hat doesnt feel unresponsive)
							if not skillTable then skillTable = {}; end
							table.insert(skillTable, {skillID, -removeXP, false})
							neuralXP_cached[skillID].xp = currentXP-removeXP
							neuralXP_cached[skillID].residue = 0
							neuralXP_cached[skillID].round = 0
							neuralXP_cached[skillID].synced = false
							--LSUtil.debugPrint("LS_NeuralHat.cacheXP, removing xp "..tostring(removeXP).." for perk "..tostring(skillID))
						else
							neuralXP_cached[skillID].residue = removeXP
							neuralXP_cached[skillID].xp = currentXP
							neuralXP_cached[skillID].synced = true
							--LSUtil.debugPrint("LS_NeuralHat.cacheXP, residue xp "..tostring(removeXP).." for perk "..tostring(skillID))
						end
					end
				end
				neuralXP_cached[skillID] = neuralXP_cached[skillID] or {}
				if removeXP == 0 or not neuralXP_cached[skillID].xp then neuralXP_cached[skillID].xp = currentXP; neuralXP_cached[skillID].synced = true; end
				neuralXP_cached[skillID].level = skillLevel
				neuralXP_cached[skillID].residue = neuralXP_cached[skillID].residue or 0
			end
		end
	end
	neuralXP_cached["delay"] = 5
	if skillTable then LSUtil.giveXPBatch(character, skillTable); end
end

LS_NeuralHat.check = function(character, charData)
	local neuralItem = LS_NeuralHat.getCompleteInfo(character)
	if charData.LSMoodles["Dunce"].Value > 0 or (neuralItem.state and neuralItem.state == 2) then
		charData.LSMoodles["NeuralHat"].Value = 0
		if neuralItem.state and neuralItem.state == 2 then charData.LSMoodles["Dunce"].Value = 1; end
		cacheXPRemove(character, charData.LSMoodles["Dunce"].Value)
		return
	elseif not neuralItem.active then
		charData.LSMoodles["NeuralHat"].Value = 0
		neuralXP_cached = nil
		return
	end
	charData.LSMoodles["NeuralHat"].Value = 1
	charData.LSMoodles["Dunce"].Value = 0
	cacheXPAdd(character, neuralItem.data, neuralItem.state)
end

local function rollBreak(durability, state)
	local func
	if LSUtil.rdm_inst:random(200) <= durability[2]*state then -- minor
		func = "OnFail"
	elseif LSUtil.rdm_inst:random(200) <= durability[1]*state then -- crit
		func = "OnCritFail"
	end
	return func
end

LS_NeuralHat.checkTenMins = function(character, charData)
	LSUtil.debugPrint("LS_NeuralHat.checkTenMins, start")
	local neuralItem = LS_NeuralHat.getCompleteInfo(character)
	if not neuralItem.active then charData.LSMoodles["NeuralHat"].Value = 0; LSUtil.debugPrint("LS_NeuralHat.checkTenMins, not active"); return; end
	if not neuralItem.data or LSUtil.inventionIsEmpty(neuralItem.data) or LSUtil.isCooldown(neuralItem.data) then -- cooldown only applies when turning off (always after state == 2, randomly otherwise)
		LSUtil.changeTexture_Item(character, neuralItem.headgear, 0)
		charData.LSMoodles["NeuralHat"].Value = 0
		if neuralItem.data then
			neuralItem.data['running'] = false
			LSInv.doDataTransmit(neuralItem.headgear, neuralItem.data)
		end
		LSUtil.debugPrint("LS_NeuralHat.checkTenMins, empty/cooldown/nodata")
		return
	end
	
	LSUtil.debugPrint("LS_NeuralHat.checkTenMins, using fuel")
	local extraConsumption
	if neuralItem.state >= 3 then
		local consumptionLvl = math.floor(neuralItem.state-(neuralItem.data['overdrive'][1]+3)) -- state 3 lvl 1 -> 3-4 -> consumption/1; state 4 lvl 3 -> 4-6 -> consumption/2
		extraConsumption = math.floor(neuralItem.data['overdrive'][3]/consumptionLvl)
	end
	LSInv.useFuel(neuralItem.headgear, 1, neuralItem.data, isClient(), extraConsumption)
	if neuralItem.data['fuelUses'] == 0 then
		LSUtil.debugPrint("LS_NeuralHat.checkTenMins, no fuel")
		if neuralItem.state == 2 then
			LSUtil.doInvCooldown(neuralItem.headgear, neuralItem.data)
			charData.LSMoodles["Dunce"].Value = 0
		end
		LSUtil.changeTexture_Item(character, neuralItem.headgear, 0)
		charData.LSMoodles["NeuralHat"].Value = 0
		neuralItem.data['running'] = false
		neuralItem.data['recentActive'] = math.max(0,neuralItem.data['recentActive']-1)
		LSInv.doDataTransmit(neuralItem.headgear, neuralItem.data)
		LSSync.updateClientData(character, charData)
		character:getEmitter():playSound("FortuneTeller_PowerDown")
		return
	end
	local checkRecent
	if neuralItem.state ~= 2 and neuralItem.data['durability'][1] > 0 and not neuralItem.data['neverBreak'] and not neuralItem.data['safe'] then
		local funcName = rollBreak(neuralItem.data['durability'], neuralItem.state)
		if funcName then
			LSInv[funcName..'NeuralHat'](character, charData, neuralItem)
			checkRecent = true
		end
	end
	if not checkRecent and neuralItem.data['recentActive'] > 0 then
		neuralItem.data['recentActive'] = math.max(0,neuralItem.data['recentActive']-1)
		LSInv.doDataTransmit(neuralItem.headgear, neuralItem.data)
	end
end

-- skill journal patch
local contextSRJ = require "Skill Recovery Journal Context"
if contextSRJ then
	local og_contextSRJ_doContextMenu = contextSRJ.doContextMenu
	function contextSRJ.doContextMenu(playerID, context, items)
		local character = getSpecificPlayer(playerID)
		local neuralHat = LS_NeuralHat.getState(character)
		if neuralHat then return; end -- remove options if player is wearing a neural hat
		return og_contextSRJ_doContextMenu(playerID, context, items)
    end
end