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

-- InvHarvester.harvestLimit must be defined might remaining uses
-- timedaction - each plant harvested adds to how much fuel is drained, if fuel reaches a very small percentage then it is replaced by empty version;
-- timedAction - maxTime is static (for anim control), but number of loop repetitions is defined by a base amount + plant number, increasing the time it takes the more plants there are to harvest (up to a limit)

InventionsMenu = InventionsMenu or {} --!

local function getHarvestRGB(plantsNum, limit)
	local pDelta = math.min(1,math.max(0,math.ceil(LSUtil.getPercentage(limit,plantsNum, false, false))/100))
	local r, g = 1-pDelta, pDelta
	return " <RGB:"..tostring(r)..","..tostring(g)..",0>"
end

local harvestAction = function(item, character, data)
	-- Check conditions again
	if not LSUtil.isValidInvItem(item) or item:isBroken() or LSUtil.inventionIsEmpty(data['inventionData']) or LSUtil.isCooldown(data['inventionData']) or
	LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character, character:getModData()) then return; end

	if LSUtil.doItemTransfer(character, item, false) then
		LSUtil.doItemEquip(character, item, false, true, false)
		character:setIsFarming(true)
		ISTimedActionQueue.add(LSInvHarvesterAction:new(character, item, data));
	end
end

local function doHarvestOption(parentMenu, character, harvester, data)
	local limit = data['inventionData']['sensors'][2]
	local plantsNum = #LSUtil.getValidPlants(character, data['inventionData']['sensors'][1],limit)
	local rgb = getHarvestRGB(plantsNum, limit)
	local option, text = parentMenu:addOption(getText("ContextMenu_InvHarvester_Harvest"), harvester, harvestAction, character, data),
	getText("Tooltip_InvHarvester_Harvest").." <LINE>"..rgb..plantsNum.." <RGB:1,1,1>".."/"..limit.." <SPACE>"..getText("Tooltip_InvHarvester_HarvestLimit")
	local disable
	local tex = 'media/ui/berries_icon.png'
	if LSUtil.inventionIsEmpty(data['inventionData']) or LSUtil.isCooldown(data['inventionData']) then
		disable = true
		tex = 'media/ui/gearsBAD_icon.png'
		text = (LSUtil.isCooldown(data['inventionData']) and getText("Tooltip_Inventions_OptionCD")) or getText("IGUI_Inventions_Stats_noFuel")
	elseif plantsNum == 0 then
		disable = true
		tex = 'media/ui/gearsBAD_icon.png'
		text = getText("Tooltip_InvHarvester_NoHarvest")
	end
	option.notAvailable = disable
	option.toolTip = LSUtil.getSimpleTooltip(text)
	option.iconTexture = getTexture(tex)
end

InventionsMenu.Harvester = function(context, parentMenu, character, item, data, itemType)
	-- Conditions
	if LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character, character:getModData()) then return; end
	-- Harvest
	doHarvestOption(parentMenu, character, item, data)
end


