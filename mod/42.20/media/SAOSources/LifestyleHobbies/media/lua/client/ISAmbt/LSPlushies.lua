
require 'ISAmbt/AmbtMng'

LSMoodHandler = LSMoodHandler or {}
LSMoodHandler.PerMin = LSMoodHandler.PerMin or {}

--ambt.goal1 - string or float / your first goal
--ambt.goal1progress - boolean or float / progress on your first goal. If goal is a string then goal progress must return a boolean (true if satisfied)
--ambt.reset - if true then all progress will reset if the player toggles this ambition off mid-progress
--ambt.offbhv - if true then ambtMng will call your ambition when updating even if not passive and not isActive, useful to add behavior when ambition was deactivated by the player
--LSAmbtMng.doComplete(player, ambt) - call when your ambition conditions are satisfied

local function getItemsTable(n)
	local t = {
		[1] = {"Base.SpiffoBig"},
		[2] = {"Base.Spiffo","Base.BorisBadger"},
		[3] = {"Base.JacquesBeaver","Base.FluffyfootBunny"},
		[4] = {"Base.FreddyFox","Base.PancakeHedgehog"},
		[5] = {"Base.MoleyMole","Base.FurbertSquirrel"}	
	}
	return t[n]
end

--[[ -- disabled. plushies will no longer be consumed
local function consumeItems(thisPlayer, itemList)
	local consumed = false
	for x=0,itemList:size() - 1 do
		local item = itemList:get(x)
		local itemCont = item:getContainer()
		if not item:IsClothing() or not thisPlayer:isEquippedClothing(item) then
			itemCont:DoRemoveItem(item)
			itemCont:setDrawDirty(true)
			consumed = true
			break
		end
	end
	return consumed
end
]]--

local function getItemsIncomplete(thisPlayer, currentList, key)
	currentList = currentList or {}
	local t = getItemsTable(key)
	for n=1, #t do
		local hasItem = false
		if #currentList > 0 then
			for p=1, #currentList do
				if t[n] == currentList[p] then hasItem = true; break; end
			end
		end
		if not hasItem then
			hasItem = thisPlayer:getInventory():getItemCount(t[n], true)
			if hasItem and hasItem > 0 then
				table.insert(currentList, t[n])
				--local consumed = consumeItems(thisPlayer, thisPlayer:getInventory():getItemsFromType(t[n], true))
				--if consumed then table.insert(currentList, t[n]); end
			end
		end
	end
	return #currentList, currentList
end

local function getItemsComplete(thisPlayer)
	local plushyNum = 0
	for key=1, 5 do
		local t = getItemsTable(key)
		for n=1, #t do
			local actualItem = thisPlayer:getInventory():getItemCount(t[n], true)
			if actualItem and actualItem > 0 then
				plushyNum = plushyNum+1
			end
		end
	end
	return plushyNum
end

local function doMoodIncrease(player, plushies)
	local unhappy, stress = 0.03*plushies, 0.0009*plushies
	moodList = {
		["Unhappiness"] = {-unhappy, false, false, true},
		["Stress"] = {-stress, false, false, true},
	}
	for k, v in pairs(moodList) do
		if not v[3] then -- refuses to add from isSet
			if not LSMoodHandler.PerMin[k] then
				LSMoodHandler.PerMin[k] = {v[1], v[2], v[3], v[4]}
			else
				LSMoodHandler.PerMin[k][1] = LSMoodHandler.PerMin[k][1]+v[1]
			end
		end
	end
end

local function LSAmbtComplete(player, ambt)
	if player:isAsleep() then return; end
	if ambt.isActive then
		local plushies = getItemsComplete(player)
		if plushies > 0 then doMoodIncrease(player, plushies); end
	end
end

local function LSAmbtActiveIncomplete(player, ambt)
	-- add conditions to add/remove progress
	-- apply buffs/debuffs if ambition has any while active and incomplete
	if player:isAsleep() then return; end
	local completed = true
	if not ambt.plushyList then ambt.plushyList = {}; end
	for n=1, 5 do
		if not ambt['goal'..n..'progress'] then ambt['goal'..n..'progress'] = 0; end
		if ambt['goal'..n..'progress'] < ambt['goal'..n] then -- additional check to ensure it won't recalculate if player had previously satisfied the condition
			ambt['goal'..n..'progress'], ambt.plushyList[n] = getItemsIncomplete(player, ambt.plushyList[n], n)
			if ambt['goal'..n..'progress'] < ambt['goal'..n] then completed = false; end
		end
	end
	if completed then ambt.plushyList = nil; ambt.offBhv = true; LSAmbtMng.doComplete(player, ambt); end
end

local function LSAmbtIsHidden(player, ambt)
	-- if your ambition starts hidden, add conditions to unlock
	
	--LSAmbtMng.doUnlock(player, ambt)
end

LSAmbtMng.LSPlushies = function(player, ambt)
	if ambt.isHidden then LSAmbtIsHidden(player, ambt); return; end
	if ambt.completed then LSAmbtComplete(player, ambt); -- ambition was completed
	elseif ambt.isActive or ambt.isPassive then LSAmbtActiveIncomplete(player, ambt); end -- ambition is in progress
end
