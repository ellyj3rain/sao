
if isClient() and not isServer() then return; end

local function resetPowerAxeDmg(item, invData, treeDmg)
	invData['power'][1] = treeDmg
	item:syncItemFields()
	LSSync.syncItemVal(item, invData, item:getType(), {['TreeDamage']=treeDmg,['MinDamage']=1.3,['MaxDamage']=3})
end

local function adjustPowerAxe(character, item, zombie)
	LSUtil.debugPrint("adjustPowerAxe, start")
	local treeDmg = 10 -- 10 is stone axe 55 is wood axe
	local invData = LSUtil.getInventionItemData(item)
	if not invData then
		LSSync.syncItemVal(item, nil, nil, {['TreeDamage']=treeDmg})
	elseif zombie and not invData['lethal'] then
		LSUtil.debugPrint("WARNING - adjustPowerAxe, hit zombie, weapon not lethal")
		return
	elseif LSUtil.inventionItemHasUses(item, invData) and treeDmg == item:getTreeDamage() then
		LSUtil.debugPrint("WARNING - adjustPowerAxe, item has fuel but treeDmg == item:getTreeDamage(), correcting values")
		LSInv.OnRefuelPowerAxe(item, item:getModData().movableData, "PowerAxe")
		return
	end
	if item:isBroken() or not LSUtil.inventionItemHasUses(item, invData) then LSUtil.drainInventionItem(item, invData); resetPowerAxeDmg(item, invData, treeDmg); return; end
	LSUtil.useInventionItem(item, invData)
	LSUtil.playSoundCharacter(character, "Gun_Blast", nil, nil, true, nil, {false, (ZombRand(10)+1)*0.1+0.5},{30, 20})
	LSUtil.playSoundCharacter(character, "Steam_Burst", nil, nil, true, nil, {false, (ZombRand(10)+1)*0.1+1},false)
	if not LSUtil.inventionItemHasUses(item, invData) then resetPowerAxeDmg(item, invData, treeDmg); end
	if invData['power'][3] then LSUtil.rollBreakdownChanceInventionItem(character, item, invData, 'PowerAxe'); end
end

local function isValidEvent(character, item)
	return LSUtil.getValidCharacter(character) and LSUtil.isValidInvItem(item)
end

local function onInvHitThump(character, item, obj)
	if not isValidEvent(character, item) then return; end
	if not instanceof(obj, "IsoTree") then print("NOT TREE"); return; end
	local itemType = item.getType and item:getType()
	if LSUtil.isValidWeapon(item) and itemType and itemType == "PowerAxe" then adjustPowerAxe(character, item, nil); end
end

local function onInvHitTree(character, item)
	if not isValidEvent(character, item) then return; end
	local itemType = item.getType and item:getType()
	if LSUtil.isValidWeapon(item) and itemType and itemType == "PowerAxe" then adjustPowerAxe(character, item); end
end

local function onInvHitZombie(zombie, character, bodyPart, item)
	if not isValidEvent(character, item) then return; end
	local itemType = item.getType and item:getType()
	if LSUtil.isValidWeapon(item) and itemType and itemType == "PowerAxe" then adjustPowerAxe(character, item, zombie); end
end

Events.OnWeaponHitTree.Add(onInvHitTree)
--Events.OnWeaponHitThumpable.Add(onInvHitThump)
Events.OnWeaponHitCharacter.Add(onInvHitZombie)

