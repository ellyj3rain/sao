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

LSInv = LSInv or {}

------------

LSInv.getImprovNum = function(improvData, invName, penalty)
	if not improvData or not invName then return 0, 0; end
	local improvDefs = LSInventionDefs.Improvements[invName]
	if not improvDefs then return 0, 0; end
	local improvNum, specialNum = 0, 0
	for k, v in pairs(improvDefs) do
		if not penalty or tostring(k) ~= "standardization" then -- standardization does not count towards total improvement number for penalty calc
			local resLvl = improvData[k] and improvData[k][1]
			--LSUtil.debugPrint("LSInv.getImprovNum, improvement "..tostring(k)..", resLvl is "..tostring(resLvl))
			if resLvl and resLvl > 0 then
				improvNum = improvNum+resLvl
				if v.special then specialNum = specialNum+resLvl; end
			end
		end
	end
	return improvNum, specialNum
end

local function isFoodProper(item)
	return item and instanceof(item, "Food") and item:getDisplayCategory() == "Food" and item:getCurrentUses() > 0 and not item:isPackaged() and not item:isPoison() and not item:getScriptItem():isCantEat() and
	not item:isFluidContainer() and not luautils.stringStarts(item:getFullType(), "Lifestyle.Paste") and not item:isAnimalSkeleton()
end

LSInv.getSynthesizerFoodItems = function(cont, acceptBad)
	local predicateFood = function(item)
		return isFoodProper(item) and item:getStringItemType() == "Food" and not item:hasTag(ItemTag.HASMETAL) and (acceptBad or (not item:isRotten() and not item:isBurnt())) and
		not item:getReplaceOnUse()
	end
	return cont:getAllEvalRecurse(predicateFood)
end

LSInv.getSynthesizerOverlay = function(key, outcome)
	local t = {
		["LS_Inventions_16"] = {good="LS_Inventions_20",bad="LS_Inventions_22"},
		["LS_Inventions_17"] = {good="LS_Inventions_21",bad="LS_Inventions_23"},
	}
	return t[key][outcome]
end

LSInv.OnActivateNeuralHat = function(character, item, state)
	if LSSync.isServerOnly() then return; end
	if not character or not character:isEquippedClothing(item) then return; end
	if data['inventionData']['fuelUses'] > 0 then
		LSUtil.changeTexture_Item(character, item, state)
	else
		LSUtil.changeTexture_Item(character, item, 0)
	end
end

LSInv.OnPreLoadNeuralHat = function(item, data, itemType, fromMenu)
	if LSSync.isServerOnly() then return; end
	local character = getPlayer()
	local state = item:getVisual():getTextureChoice() -- 0 off 1 on 2 bad 3 overdrive
	local isDisabled = LSUtil.inventionIsEmpty(data['inventionData']) or LSUtil.isCooldown(data['inventionData']) or not item:isEquipped()
	if isDisabled and state ~= 0 then
		LSUtil.changeTexture_Item(character, item, 0)
	end
end

LSInv.OnRefuelPowerAxe = function(item, data, itemType)
	LSInv.updateInventionStat(item, data, 'power', 'PowerAxe', 1, not data['inventionData']['lethal'])
	if data['inventionData']['lethal'] then
		local powerImprovLvl = math.max(1,data['improvementData']['power'][1])
		local minDmg, maxDmg = 1.3*powerImprovLvl, 3*powerImprovLvl
		--setPowerAxeDmg(item, minDmg, maxDmg)
		LSSync.syncItemVal(item, data['inventionData'], itemType, {['MinDamage']=minDmg,['MaxDamage']=maxDmg})
	end
end

local function checkFuel(item, data, itemType)
	if data['inventionData']['fuelUses'] <= 0 and data['inventionData']['power'][1] > 10 then
		data['inventionData']['power'][1] = 10
		LSSync.syncItemVal(item, data['inventionData'], itemType)
	elseif (data['inventionData']['power'][1] <= 10 or item:getTreeDamage() <= 10) and data['inventionData']['fuelUses'] > 0 then
		LSInv.OnRefuelPowerAxe(item, data)
	else
		LSInv.updateInventionScripts(item, data['inventionData'], itemType, true)
	end
end

LSInv.OnPreLoadPowerAxe = function(item, data, itemType, fromMenu)
	-- fueled and out of fuel behavior
	checkFuel(item, data, itemType)
end

LSInv.OnPreLoadHarvester = function(item, data, itemType, fromMenu)
	if not fromMenu then LSInv.updateInventionScripts(item, data['inventionData'], itemType, true); end
end

LSInv.updateInvItem = function(item, itemType)
	LSUtil.debugPrint("LSInv.updateInvItem, updating")
	local data = InventionsMenu.updateInvData(item, itemType)
	if not data or not data['inventionData']['enabled'] then return; end
	if LSInv['OnPreLoad'..itemType] then LSInv['OnPreLoad'..itemType](item, data, itemType, false); end
end

local function isValidEvent(character, item)
	return LSUtil.getValidCharacter(character) and LSUtil.isValidInvItem(item)
end

local function onEquipInvention(character, item)
	if not isValidEvent(character, item) then return; end
	local itemType = item.getType and item:getType()
	if itemType and LSInventionDefs.ItemScript[itemType] then LSInv.updateInvItem(item, itemType); end
end

if not isServer() or isClient() then Events.OnEquipPrimary.Add(onEquipInvention); end
