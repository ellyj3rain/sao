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

InventionsMenu = InventionsMenu or {};

InventionsMenu.loadDefs = function(inv, invDefs, improvDefs, data, customName)
	local seen, changed = {}, false
	-- add missing data
	for k, v in pairs(invDefs) do
		seen[k] = true
		if data['inventionData'][k] == nil then data['inventionData'][k] = v; changed = true; end
	end
	-- remove unused data
	for k, v in pairs(data['inventionData']) do
		if not seen[k] then data['inventionData'][k] = nil; changed = true; end
	end
	-- clear table
	seen = {}
	-- add missing improvement data (if missing then it will always be level 0, but we need the keys for debug)
	for k, v in pairs(improvDefs) do
		seen[k] = true
		if data['improvementData'][k] == nil then
			local maxNum = 1 -- max value of 1 means inventionData uses result value
			if v and v.repeatable then maxNum = #v.repeatable; end
			data['improvementData'][k] = {0,maxNum}
			changed = true
		end
	end
	-- remove unused data
	for k, v in pairs(data['improvementData']) do
		if not seen[k] then data['improvementData'][k] = nil; changed = true; end
	end
	if changed then
		LSInv.doDataTransmit(inv, data['inventionData'])
	elseif LSInventionDefs.Items[customName] and LSInventionDefs.Items[customName]['autoSync'] then
		LSInv.updateInventionScripts(inv, data['inventionData'], customName, true)
	end
	return data
end

InventionsMenu.resetData = function(inv, data, customName)
	local ogInvDef = LSInventionDefs and LSInventionDefs.Items and LSInventionDefs.Items[customName]
	local ogImprovDef = LSInventionDefs and LSInventionDefs.Improvements and LSInventionDefs.Improvements[customName]
	if not ogInvDef or not ogInvDef then return; end
	local invDefs = LSUtil.deepCopy(ogInvDef)
	local improvDefs = LSUtil.deepCopy(ogImprovDef)
	data['inventionData'] = {}
	for k, v in pairs(invDefs) do
		data['inventionData'][k] = v
	end
	data['improvementData'] = {}
	for k, v in pairs(improvDefs) do
		local maxNum = 1
		if v and v.repeatable then maxNum = #v.repeatable; end
		data['improvementData'][k] = {0,maxNum}
	end
	LSInv.doDataTransmit(inv, data['inventionData'])
end

local function getOrCreateInventionData(inv, invDefs, improvDefs, customName)
	if not invDefs or not improvDefs then return false; end
	if not inv:getModData().movableData then inv:getModData().movableData = {}; end
	local data = inv:getModData().movableData
	if not data then return false; end
	if not data['inventionData'] then data['inventionData'] = {}; end
	if not data['improvementData'] then data['improvementData'] = {}; end
	data = InventionsMenu.loadDefs(inv, invDefs, improvDefs, data, customName)
	return data
end

InventionsMenu.updateInvData = function(obj, CN)
	local customName = CN or LSUtil.getObjCustomName(obj)
	if not customName then return false; end
	local ogInvDef = LSInventionDefs and LSInventionDefs.Items and LSInventionDefs.Items[customName]
	local ogImprovDef = LSInventionDefs and LSInventionDefs.Improvements and LSInventionDefs.Improvements[customName]
	if not ogInvDef or not ogInvDef then return false; end
	local invDefs = LSUtil.deepCopy(ogInvDef)
	local improvDefs = LSUtil.deepCopy(ogImprovDef)
	local data = getOrCreateInventionData(obj, invDefs, improvDefs, customName)
	return data
end

InventionsMenu.hasInvData = function(inv)
	local data = inv and inv.getModData and inv:getModData()
	return data and data.movableData and data.movableData['inventionData'] and data.movableData['improvementData']
end

local function doDebugSubOptions(subMenu, character, inv, data, invName, customName)
	local funcType = "Item"
	if instanceof(inv, "IsoObject") then funcType = "Obj"; end
	-- reset
	local resetOption = subMenu:addOption("Reset Data",inv,InventionsMenu.resetData,data,customName)
	-- edit
	local editOption = subMenu:addOption("Edit Values",character,InventionsMenu.editData,invName,inv,data,customName)
	-- force fix
	if data['inventionData']['isBroken'] or (funcType == "Item" and inv:isBroken()) then
		local fixOption = subMenu:addOption("Fix",character,InventionsMenu['onFix'..funcType],inv,data['inventionData'],false,true)
	-- reset cooldown
	elseif LSUtil.isCooldown(data['inventionData']) then
		local fixOption = subMenu:addOption("Reset Cooldown",inv,InventionsMenu.onResetCooldown,data)
	end
	if data['inventionData']['fuelUses'] and data['inventionData']['fuelUses'] < data['inventionData']['fuelContainer'][1] then
		local fuelOption = subMenu:addOption("Refuel",inv,InventionsMenu['onRefuel'..funcType], character, data, customName, true)
	end
	if funcType == "Item" then
		local weightTest = subMenu:addOption("Weight 1 test",inv,InventionsMenu['onWeightTest'..funcType])
	end
end

InventionsMenu.onWeightTestItem = function(inv)
	inv:setCustomWeight(true)
	inv:setActualWeight(1)
	inv:setWeight(1)
	inv:syncItemFields()
	ISInventoryPage.dirtyUI()
end

local function buildMenuSupport(context, buildOption, ogSubMenu)
	local parentMenu = ogSubMenu or context
	local subMenu = parentMenu:getNew(parentMenu)
	--if ogSubMenu then subMenu = ogSubMenu:getNew(ogSubMenu); else subMenu = ISContextMenu:getNew(context); end
	context:addSubMenu(buildOption, subMenu)
	function subMenu:closeAll()
		local option = self:getIsVisible() and self.mouseOver and self.mouseOver ~= -1 and self.options and self.options[self.mouseOver]
		if option and option.notClose then return; end
		self:hideAndChildren()
		local isJoypad = JoypadState.players[self.player+1]
		local parent = self.parent
		if isJoypad and (parent == nil) then
			setJoypadFocus(self.player, self.origin)
		end
		while parent do
			parent:setVisible(false)
			if isJoypad and (parent.parent == nil) then
				setJoypadFocus(self.player, parent.origin)
			end
			parent = parent.parent
		end
	end
	return subMenu
end

local function getObjContextMenu(context, objName)
	local subMenu
    for i = 1, #context.options do
        local option = context.options[i]
        if option and option.name and option.name == objName then
			if option.subOption ~= nil then subMenu = context:getSubMenu(option.subOption); end
			if not subMenu then
				subMenu = ISContextMenu:getNew(context)
				context:addSubMenu(option, subMenu)
            end
			return subMenu:addOptionOnTop(getText("ContextMenu_Inventions_Invention")), subMenu
        end
    end
    return context:addOptionOnTop(objName), subMenu
end

InventionsMenu.doBuildMenu = function(player, context, worldobjects, inv, spriteName, customName, groupName, DebugOption)
	-- core
	local character = getSpecificPlayer(player)
	if LSUtil.isCharBusy(character) then return; end
	if not LSUtil.isValidObj(inv, spriteName) then return; end
	-- data
	local data = InventionsMenu.updateInvData(inv, customName)
	if not data then return; end
	-- main option
	local invTex, invName = LSUtil.getObjTexAndText(spriteName)
	--local invName = LSUtil.getMoveableDisplayName("Invention", inv, customName, groupName)
	local buildOption, ogSubMenu = getObjContextMenu(context, invName)
	local tex = (ogSubMenu and getTexture('media/ui/IW_icon.png')) or invTex
	-- LSUtil.getObjTexture(spriteName, "E")
	buildOption.iconTexture = tex
	local subMenu = buildMenuSupport(context, buildOption, ogSubMenu)

	if data['inventionData']['enabled'] then --!
		-- preload
		if LSInv['OnPreLoad'..customName] then LSInv['OnPreLoad'..customName](inv, data, customName, true); end
		-- repair and stats sub options
		local isUnusable = InventionsMenu.doRepairStatsOptions(context, subMenu, character, inv, data, invName, customName)
		if not isUnusable then
			-- refuel sub option
			if data['inventionData']['fuelUses'] and not data['inventionData']['running'] then
				InventionsMenu.doRefuelOption(context, subMenu, character, inv, data, customName)
			end
			-- sub options (invention specific)
			if InventionsMenu[customName] then InventionsMenu[customName](context, subMenu, character, inv, data, spriteName); end
		end
	end
	-- debug stuff
	if not LSUtil.hasAdminRights() then return; end
	local debugOption = subMenu:addOption("Debug Tools")
	local debugSubMenu = subMenu:getNew(subMenu);
	context:addSubMenu(debugOption, debugSubMenu)
	doDebugSubOptions(debugSubMenu, character, inv, data, invName, customName)
end

InventionsMenu.editData = function(character, invName, inv, data, customName)
	local playerNum = character:getPlayerNum()
	local width, height = 150, 50
	local newUI = LSDebugInventions:new((getPlayerScreenWidth(playerNum)-width)/2,(getPlayerScreenHeight(playerNum)-height)/2,width,height,invName, inv, data, customName)
    newUI:initialise();
    newUI:addToUIManager()
end

InventionsMenu.onFixObj = function(character, obj, invData, reqList, admin)
	-- add stuff
	if admin then
		invData['isBroken'] = false
		invData['cooldown'] = false
		invData['repairList'] = false
		LSSync.transmit(obj)
		return
	end
	local item = LSUtil.getItemAndEquip(character, 'Screwdriver', false, true, false)
	if item and reqList and LSUtil.walkToAdj(character, obj) and LSUtil.hasItemsOnChar(character, reqList) then
		ISTimedActionQueue.add(LSFixAction:new(character, obj, invData, reqList, 200))
	end
end

InventionsMenu.onFixItem = function(character, inv, invData, reqList, admin)
	-- add stuff
	if admin then
		LSUtil.doInvCooldown(inv, invData)
		LSUtil.fillInventionItem(invData)
		if invData['isBroken'] then invData['isBroken'] = false; end
		if invData['cooldown'] then invData['cooldown'] = false; end
		invData['repairList'] = false
		LSSync.syncItemVal(inv, invData, inv:getType(), {['setBroken']={'isBroken',false},['Condition']=inv:getConditionMax()})
		return
	end
	local item = LSUtil.getItemAndEquip(character, 'Screwdriver', false, true, false)
	if item and reqList and LSUtil.hasItemsOnChar(character, reqList) then
		ISTimedActionQueue.add(LSFixItemAction:new(character, inv, invData, reqList, 200));
	end
end

InventionsMenu.onResetCooldown = function(inv, data)
	data['inventionData']['cooldown'] = false
	LSSync.transmit(inv)
end

local function refuelAdmin(inv, data, invName)
	LSUtil.fillInventionItem(data['inventionData'])
	if LSInv['OnRefuel'..invName] then LSInv['OnRefuel'..invName](inv, data, invName); else LSSync.transmit(inv); end
end

local function getFuelItem(character, invData)
	return LSUtil.getItemAndEquip(character, invData['fuelTag'], invData['fuelItem'], true, false, not invData['fuelLiquid'], false, invData['fuelLiquid'])
end

local function getRefuelTime(fuelItem, invData)
	local actionTime = invData['fuelingBaseTime'] or 100
	if fuelItem.IsDrainable and fuelItem:IsDrainable() then
		actionTime = actionTime + math.min(fuelItem:getCurrentUsesFloat() * 40, math.max(50,invData['fuelContainer'][1]-invData['fuelUses']*25))
	elseif invData['fuelLiquid'] then
		local missingUses = math.min(0, invData['fuelContainer'][1]-invData['fuelUses'])
		local fuelAmount = LSUtil.getItemFluidAmount(fuelItem, invData['fuelLiquid'])
		local fuelUnitsAvailable = fuelAmount/invData['fuelUseDelta']
		local usesToAdd = math.min(missingUses, math.floor(fuelUnitsAvailable/invData['fuelConsumption']))
		actionTime = actionTime + (usesToAdd*5)
	end
	return actionTime
end

InventionsMenu.onRefuelBattery = function(inv, character, data, name)
	local invData = data['inventionData']
	local batteryItem
	local batteryName = "Base."..invData['fuelItem'] -- should change this eventually to allow for custom items
	if not invData['hasBattery'] then
		batteryItem = LSUtil.getFullerDrainable(character, batteryName, data['inventionData']['fuelMin'])
		if not batteryItem then return; end
	end
	ISTimedActionQueue.add(LSAddRemoveBattery:new(character, inv, name, data['inventionData'], batteryItem, batteryName))
end

InventionsMenu.onRefuelAll = function(inv, character, data, name, admin)
	if admin then refuelAdmin(inv, data, name); return; end
	if LSUtil.isCharBusy(character) or data['inventionData']['running'] then return; end
	if data['inventionData']['fuelBattery'] then InventionsMenu.onRefuelBattery(inv, character, data, name); return; end
	local fuelItem = getFuelItem(character, data['inventionData'])
	if not fuelItem then return; end
	local actionTime = getRefuelTime(fuelItem, data['inventionData'])
	ISTimedActionQueue.add(LSAddFuelAction:new(character, inv, name, data['inventionData'], data['inventionData']['fuelUses'], fuelItem, actionTime))
end

InventionsMenu.onRefuelItem = function(inv, character, data, itemType, admin)
	if not LSUtil.isValidInvItem(inv) or (LSUtil.inventionIsFull(data['inventionData']) and not data['inventionData']['fuelBattery']) then return; end
	InventionsMenu.onRefuelAll(inv, character, data, itemType, admin)
end

InventionsMenu.onRefuelObj = function(inv, character, data, customName, admin)
	if not LSUtil.isValidObj(inv, customName) or (LSUtil.inventionIsFull(data['inventionData']) and not data['inventionData']['fuelBattery']) then return; end
	InventionsMenu.onRefuelAll(inv, character, data, customName, admin)
end

InventionsMenu.onChangeStatsTooltip = function(tooltip)
	if not tooltip or not tooltip.descList or #tooltip.descList == 1 or (tooltip.owner and not tooltip.owner:isReallyVisible()) then return; end
	local n = 1
	if tooltip.descCurrent < #tooltip.descList then n = tooltip.descCurrent+1; end
	tooltip.description = tooltip.descList[n]
	tooltip.descCurrent = n
	tooltip:doLayout()
	getSoundManager():playUISound('UI_Note_Appear')
end

InventionsMenu.doInventoryMenu = function(player, context, items, inv)
	-- core
	if not LSUtil.isValidInvItem(inv) then return; end
	local character = LSUtil.getValidPlayer(player)
	if not character then return; end
	local itemType = inv:getType()
	-- data
	local data = InventionsMenu.updateInvData(inv, itemType)
	if not data then return; end
	-- main option
	local invName = inv:getDisplayName() or inv:getScriptItem():getDisplayName() or "Nameless Invention"
	local buildOption = context:addOptionOnTop(invName)
	buildOption.iconTexture = inv:getTexture()
	local subMenu = buildMenuSupport(context, buildOption)

	if data['inventionData']['enabled'] then
		-- preload
		if LSInv['OnPreLoad'..itemType] then LSInv['OnPreLoad'..itemType](inv, data, itemType, true); end --!
		-- repair and stats sub options
		local isUnusable = InventionsMenu.doRepairStatsOptions(context, subMenu, character, inv, data, invName, itemType)
		if not isUnusable then --!
			-- refuel sub option
			if data['inventionData']['fuelUses'] and not data['inventionData']['running'] then
				InventionsMenu.doRefuelOption(context, subMenu, character, inv, data, itemType)
			end
			-- sub options (invention specific)
			if InventionsMenu[itemType] then InventionsMenu[itemType](context, subMenu, character, inv, data, itemType); end --!
		end
	end
	-- debug stuff
	if not LSUtil.hasAdminRights() then return; end
	local debugOption = subMenu:addOption("Debug Tools")
	local debugSubMenu = subMenu:getNew(subMenu);
	context:addSubMenu(debugOption, debugSubMenu)
	doDebugSubOptions(debugSubMenu, character, inv, data, invName, itemType)
end

InventionsMenu.getAdditionalStatsDescObj = function(object, data, cN)
	local main, improv, other
	local iN, oN = 1, 1
	if InventionsMenu['getAdditionalStatsDesc'..cN] then main, improv, other = InventionsMenu['getAdditionalStatsDesc'..cN](object, data); end
	if data['inventionData']['reqWater'] then
		local waterAmount = tostring((object:hasWater() and object:getFluidAmount()) or 0)
		waterAmount = waterAmount.." <SPACE>"..getText("IGUI_FitnessNeedItem",data['inventionData']['waterUsage'][1])
		local wTxtM, wTxtO = " <RGB:0.8,0.6,0.6>"..getText("IGUI_RequiresWaterSupply"), " <RGB:0.8,0.6,0.6>"..waterAmount
		if data['inventionData']['noPlumbing'] then wTxtM = " <RGB:0.5,0.9,0.5>"..getText("Tooltip_WaterUnlimited"); wTxtO = wTxtM;
		elseif LSInv.InvHasWater(object, data['inventionData']) then wTxtM, wTxtO = " <RGB:0.6,0.8,0.6>"..getText("IGUI_RainCollectorHasWater"), " <RGB:0.6,0.8,0.6>"..waterAmount ; end
		if main then main = main.." <LINE><LINE><RGB:0.9,0.9,0.9>"..getText("IGUI_ItemCat_Water")..": <SPACE>"..wTxtM;
		else main = " <TEXT><LINE><RGB:0.9,0.9,0.9>"..getText("IGUI_ItemCat_Water")..": <SPACE>"..wTxtM; end
		if other then other = other.." <LINE><LINE><RGB:0.9,0.9,0.9>"..getText("IGUI_ItemCat_Water")..": <SPACE>"..wTxtO; oN = oN+1;
		else other = " <TEXT><RGB:0.9,0.9,0.9>"..getText("IGUI_ItemCat_Water")..": <SPACE>"..wTxtO; end
	end
	if data['inventionData']['reqPower'] then
		local powerText = " <RGB:0.8,0.6,0.6>"..getText("IGUI_RadioRequiresPowerNearby")
		if data['inventionData']['selfPowered'] then powerText = " <RGB:0.5,0.9,0.5>"..getText("Tooltip_WaterUnlimited");
		elseif LSUtil.sqrHasEnergy(object:getSquare()) then powerText = " <RGB:0.6,0.8,0.6>"..getText("IGUI_RadioPowerNearby"); end
		if main then main = main.." <LINE><LINE><RGB:0.9,0.9,0.9>"..getText("IGUI_RadioPower")..": <SPACE>"..powerText;
		else main = "<TEXT><LINE><RGB:0.9,0.9,0.9>"..getText("IGUI_RadioPower")..": <SPACE>"..powerText; end
	end
	return {main, improv, iN, other, oN} -- main page, improvements page and number (for pages), other and number
end

InventionsMenu.getAdditionalStatsDescItem = function(item, data, cN)
	local main, improv, other
	local iN, oN = 1, 1
	if InventionsMenu['getAdditionalStatsDesc'..cN] then main, improv, iN, other, oN = InventionsMenu['getAdditionalStatsDesc'..cN](item, data); end

	
	return {main, improv, iN, other, oN} -- main page, improvements page and number (for pages), other and number
end

InventionsMenu.doRepairStatsOptions = function(context, parentMenu, character, inv, data, invName, cN)
	local bhs, ghs, mhs = " <RGB:1,0,0> "," <RGB:0,1,0> "," <RGB:1,1,0> "
	local toolTipLineWidth = getTextManager():MeasureStringX(UIFont.NewSmall, getText('IGUI_Inventions_repairPenalty'))+200
	local funcType = "Item"
	if instanceof(inv, "IsoObject") then funcType = "Obj"; end
	-- repair and stuff
	-- broken
	if data['inventionData']['isBroken'] or (funcType == "Item" and inv:isBroken()) then
		local researchLevels, totalResearch = 0, 0
		for k, v in pairs(data['improvementData']) do
			researchLevels = researchLevels+v[1]
			totalResearch = totalResearch+v[2]
		end
		local percentCompleted = 0
		if researchLevels > 0 then percentCompleted = math.ceil((researchLevels*10)/totalResearch); end -- returns 1, 2, 3 ... 10
		percentCompleted = math.min(10, math.max(1, percentCompleted))
		
		local reqList = LSInv.getInventionDefinitionsMult(inv, percentCompleted, data['inventionData']['costDefs'][1], data['inventionData'], {true})
		local disable, description, footNote = LSUtil.getInventionFixParams(reqList, character, bhs, mhs, ghs)
		local fixTooltip = LSUtil.getNewTooltip(description, nil, nil, footNote)

		local fixOption = parentMenu:addOption(getText('ContextMenu_Inventions_Fix'),character,InventionsMenu['onFix'..funcType],inv,data['inventionData'],reqList.reqRes,false)
		fixOption.notAvailable = disable
		fixOption.toolTip = fixTooltip
		fixOption.iconTexture = getTexture('media/ui/maintenance_icon.png')
		return true
	end
	-- stats -- should show a breakdown of what the invention does and its stats with researched improvements and percentages
	local tex = (funcType == "Obj" and inv:getTextureName()) or inv:getTexture():getName()
	local statsAddArgs = InventionsMenu['getAdditionalStatsDesc'..funcType](inv, data, cN) --!
	local statsDesc = LSUtil.getInventionStatsParams(data, tex, invName, character, cN, statsAddArgs)
	local statsTooltip = LSUtil.getNewTooltip(statsDesc[1], nil, nil, nil, toolTipLineWidth, {r=0, g=0, b=0, a=0.7})
	statsTooltip.descList = statsDesc
	statsTooltip.descCurrent = 1
	--local statParentMenu = parentMenu
	local statsOption = parentMenu:addOption(getText('ContextMenu_Inventions_Stats'),statsTooltip,InventionsMenu.onChangeStatsTooltip)
	statsOption.toolTip = statsTooltip
	statsOption.iconTexture = getTexture('media/ui/bookWrite_icon.png')
	statsOption.notClose = true

	-- missing power or missing water or cooldown/recharging
	local tooltipTxt, optionTxt, optionIcon, green
	if not LSInv.InvHasPower(inv, data['inventionData']) then
		optionTxt, optionIcon = 'ContextMenu_Inventions_NoPower', 'noPower_icon'
	elseif not LSInv.InvHasWater(inv, data['inventionData']) then
		optionTxt, optionIcon = 'ContextMenu_Inventions_NoWater', 'noWater_icon'
	elseif data['inventionData']['cooldownTime'] then
		local rechargeText, ready = 'Inventions_Ready', ""
		tooltipTxt = getText('Tooltip_'..rechargeText)
		if LSUtil.isCooldown(data['inventionData']) then
			ready, rechargeText = "No",'Inventions_Recharging'; tooltipTxt = getText('Tooltip_'..rechargeText..'N', math.floor(data['inventionData']['cooldown']-getGameTime():getWorldAgeHours()))
		else
			green = true
		end
		optionTxt, optionIcon = 'ContextMenu_'..rechargeText, 'shareknowledge'..ready..'_icon'
	end
	if not optionTxt then return false; end
	local rechargeOption = parentMenu:addOption(getText(optionTxt))
	if tooltipTxt then
		local rechargeTooltip = LSUtil.getSimpleTooltip(tooltipTxt)
		rechargeOption.toolTip = rechargeTooltip
	end
	rechargeOption.iconTexture = getTexture('media/ui/'..optionIcon..'.png')
	rechargeOption.goodColor = green
	-- if LSUtil.walkToFront(player, Invention) then
	return false
end

InventionsMenu.doRefuelOption = function(context, parentMenu, character, invention, data, cN)
	local bhs, ghs, mhs = " <RGB:1,0,0> "," <RGB:0,1,0> "," <RGB:1,1,0> "
	local funcType = "Item"
	if instanceof(invention, "IsoObject") then funcType = "Obj"; end
	local invData = data['inventionData']
	local disable, description, footNote = LSUtil.getInventionFuelParams(invData, data['improvementData'], character, cN, invention, {bhs, mhs, ghs})
	local fuelTooltip = LSUtil.getNewTooltip(description, nil, nil, footNote)
	local fuelTitle, fuelIcon = 'ContextMenu_Inventions_Refuel', 'Petrol_icon'
	local customTexture
	if invData['fuelBattery'] then
		local tex, text = LSUtil.getItemTexAndTextNew("Base."..invData['fuelItem']) -- change this later
		if tex then customTexture = tex; end
		if invData['hasBattery'] then
			fuelTitle = getText('ContextMenu_Inventions_RemoveBattery',text,LSUtil.getPercentage(100,invData['fuelUses'])).."%%)"
			fuelIcon = 'LightSourceRadial_RemoveBattery'
		else
			fuelTitle = getText('ContextMenu_Inventions_AddBattery',text)
			fuelIcon = 'LightSourceRadial_InsertBattery'
		end
	else
		fuelTitle = getText(fuelTitle)
	end
	
	local fuelOption = parentMenu:addOption(fuelTitle,invention,InventionsMenu['onRefuel'..funcType],character,data,cN,false)
	fuelOption.notAvailable = disable
	fuelOption.toolTip = fuelTooltip
	fuelOption.iconTexture = customTexture or getTexture('media/ui/'..fuelIcon..'.png')
end