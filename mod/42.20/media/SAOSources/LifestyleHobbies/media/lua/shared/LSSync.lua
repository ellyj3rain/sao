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

----- setTreeDamage when set server-side will apply new damage correctly, but still retrieves script damage in UI (recommendation - use moddata to show tree dmg value)

LSSync = {}

LSSync.isNotServer = function() -- includes mp client, coop, singleplayer
	return (isClient() or not isServer())
end

LSSync.isClientOnly = function() -- excludes coop, singleplayer
	return isClient() and not isServer()
end

LSSync.isServerOnly = function() -- excludes coop, singleplayer
	return isServer() and not isClient()
end

LSSync.isSingleplayer = function() -- excludes coop, multiplayer
	return not isServer() and not isClient()
end
------------ 

LSSync.updateClientData = function(character, data)
	if LSSync.isClientOnly() then sendClientCommand(character, "LS", "SavePlayerData", {data}); end
end

LSSync.rewriteData = function(entity, newData)
	local data = entity:getModData()
	local target = (LSSync.isSingleplayer() and LSUtil.deepCopy(newData)) or newData
	for k in pairs(data) do
		data[k] = nil
	end
	for k, v in pairs(target) do
		data[k] = v
	end
end

function LSSync.getItemServer(id, cont)
	--if not isServer() then return false; end
	local predicateItem = function(item)
		return item and item:getID() == id
	end
	return cont and cont:getFirstEvalRecurse(predicateItem)
end
--[[ -- not necessary as long as item isn't replaced/moved
function LSSync.getItemEditableMovData(item, key) -- returns full (or specific) mov data table or an exact copy for editing before mp sync, useful client-side only
	local data = LSUtil.isValidInvItem(item) and item.getModData and item:getModData()
	if not data then return nil; end
	data.movableData = data.movableData or {}
	if key then
		data.movableData[key] = data.movableData[key] or {}
		return (isClient() and LSUtil.deepCopy(data.movableData[key])) or data.movableData[key]
	end
	return (isClient() and LSUtil.deepCopy(data.movableData)) or data.movableData
end
]]--
function LSSync.updateAndSend(entity, keys, data, itemStats)
	if not isServer() or not entity then LSUtil.debugPrint("LSSync.updateAndSend - not server or not entity, returning"); return; end
	local oldData = entity:getModData()
	oldData.movableData = oldData.movableData or {}
	if keys then
		for k, keyData in pairs(keys) do
			oldData.movableData[k] = {}
			for j, l in pairs(keyData) do
				oldData.movableData[k][j] = l
			end
		end
	elseif data then
		for k, v in pairs(data) do
			oldData.movableData[k] = v
		end
	end
	--if entity:getModData().movableData['inventionData'] and entity:getModData().movableData['inventionData']['cooldown'] then print("INV HAS COOLDOWN"); else print("INV HAS NO COOLDOWN"); end
	if instanceof(entity, "IsoObject") then
		entity:transmitModData()
	elseif instanceof(entity, "InventoryItem") then
		if LSInv.getInventionData(entity) or itemStats then LSSync.syncItemVal(entity, oldData.movableData['inventionData'], entity:getType() or "", itemStats); else entity:syncItemFields(); end
	end
end

local function getObjSpriteName(obj)
	local sprite = obj.getSprite and obj:getSprite()
	local spriteName = sprite and sprite:getName()
	if not spriteName then spriteName = (obj.getSpriteName and obj:getSpriteName()) or (obj.getTextureName and obj:getTextureName()); end
	return spriteName or "none"
end

function LSSync.transmitObjMovData(obj, keys, data)
	if LSSync.isClientOnly() then
		local spriteName = getObjSpriteName(obj)
		sendClientCommand("LS", "SyncObjMovData", {{obj:getX(),obj:getY(),obj:getZ(),spriteName}, keys, data})
		return
	end
	LSSync.updateAndSend(obj, keys, data)
end

function LSSync.transmitItemMovData(item, character, srcObj, keys, data, itemStats)
	if LSSync.isClientOnly() then
		if srcObj then
			local spriteName = getObjSpriteName(srcObj)
			sendClientCommand("LS", "SyncItemData_FromObj", {item:getID(),{srcObj:getX(),srcObj:getY(),srcObj:getZ(),spriteName}, keys, data, itemStats});
		elseif character then sendClientCommand(character, "LS", "SyncItemData_FromPlayer", {item:getID(), keys, data, itemStats}); end
		return
	end
	if character and itemStats and itemStats['setBroken'] then LSUtil.removeItemOnChar(character, item); end
	LSSync.updateAndSend(item, keys, data, itemStats)
end

function LSSync.transmit(entity, character, obj, itemStats)
	local data = entity and entity.getModData and entity:getModData()
	local movData = data and data.movableData
	if not movData then return; end
	if LSSync.isSingleplayer() then
		if itemStats and LSUtil.isValidInvItem(entity) then LSSync.syncItemVal(entity, movData['inventionData'], entity:getType(), itemStats); end -- handles attempts to change itemStats in singleplayer
		return
	end
	local srcObj = obj
	if instanceof(entity, "IsoObject") then
		LSSync.transmitObjMovData(entity, nil, movData)
	elseif instanceof(entity, "InventoryItem") then
		character = character or (LSSync.isNotServer() and getPlayer())
		if not srcObj then
			local parent = LSUtil.getItemParent(entity)
			if instanceof(parent, "IsoObject") and not instanceof(parent, "IsoPlayer") then srcObj = parent; end
		end
		LSSync.transmitItemMovData(entity, character, srcObj, nil, movData, itemStats)
	end
end

local function getModifiersTotalVal(data, list)
	local total = 0
	for n=1,#list do
		local mod = list[n]
		if type(mod) == "table" then
			for i=1,#mod do
				if mod[i] and data[mod[i]] and data[mod[i]][i] then
					total = total+data[mod[i]][i]
					break
				end
			end
		elseif type(mod) == "string" then
			total = total+data[mod]
		else
			total = total+mod
		end
	end
	return total
end

function LSSync.syncItemVal(item, data, itemType, itemStats, fromServer)
	if not LSUtil.isValidInvItem(item) then return; end

	if not fromServer and LSSync.isClientOnly() then -- avoids recursive logic in coop
		local parent = LSUtil.getItemParent(item)
		if parent then 
			if instanceof(parent, "IsoObject") and not instanceof(parent, "IsoPlayer") then
				LSSync.transmit(item, nil, parent, itemStats, true)
			else
				LSSync.transmit(item, getPlayer(), nil, itemStats, true)
			end
		end
		return
	end

	local modifiers = data and itemType and LSInventionDefs.Modifiers[itemType]
	
	if modifiers and data then
		for k, v in pairs(modifiers) do
			local pos, neg = 0, 0
			if v.add then
				pos = getModifiersTotalVal(data, v.add)
			end
			if v.subtract then
				neg = getModifiersTotalVal(data, v.subtract)
			end
			local total = math.max(v.min, pos-neg)
			if data[k] then
				if v.key then data[k][v.key] = total; else data[k] = total; end
			end
		end
	end

	local scriptArgs = data and itemType and LSInventionDefs.ItemScript[itemType]
	
	LSUtil.debugPrint(" LSSync.syncItemVal, itemType is "..tostring(itemType))
	
	if not scriptArgs and not itemStats then return; end
	
	--item:setCustomName(true)
	if scriptArgs then
		for k, v in pairs(scriptArgs) do
			if data[k] then
				if type(v) == "table" then
					for n=1,#v do
						if v[n] then
							LSUtil.setItemVal(item, 'get'..v[n], 'set'..v[n], data[k][n])
						end
					end
				else
					LSUtil.setItemVal(item, 'get'..v, 'set'..v, data[k])
				end
			end
		end
	end
	if itemStats then
		if itemStats['setBroken'] and LSSync.isNotServer() then LSUtil.removeItemOnChar(getPlayer(), item); end
		for k, v in pairs(itemStats) do
			if type(v) == "table" then
				LSUtil.setItemVal(item, v[1], k, v[2])
			else
				LSUtil.setItemVal(item, 'get'..k, 'set'..k, v)
			end
		end
	end
	--item:setCustomName(true)

	if isServer() then
		LSUtil.debugPrint("(server) LSSync.syncItemVal, updating item stats")
		item:syncItemFields()
		sendItemStats(item)
		if LSUtil.isValidWeapon(item) then
			local player = item:getUsingPlayer()
			if player then syncHandWeaponFields(player, item); end
		end
		--item:sendSyncEntity(nil)
		if not isClient() then
			-- send syncItemVal back to client holding the weapon if syncItemVal was initially started by server (some attributes fail to sync properly)
			local parent = LSUtil.getItemParent(item)
			if parent then 
				if instanceof(parent, "IsoPlayer") then
					sendServerCommand(parent, "LS", "SyncItemVal", {item:getID(), data, itemStats})
				end
			end
		end
	end

end

function LSSync.reloadInventionObjModifiers(obj, data, invType)
	if isServer() or not data then return; end
	local modifiers = LSInventionDefs.Modifiers[invType]
	if not modifiers then return; end

	for k, v in pairs(modifiers) do
		local pos, neg = 0, 0
		if v.add then
			pos = getModifiersTotalVal(data, v.add)
		end
		if v.subtract then
			neg = getModifiersTotalVal(data, v.subtract)
		end
		local total = math.max(v.min, pos-neg)
		if v.key then data[k][v.key] = total; else data[k] = total; end
	end

	LSSync.transmit(obj)
end
