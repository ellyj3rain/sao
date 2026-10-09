
require "WardrobeFunctions"

LSWardrobeContextMenu = LSWardrobeContextMenu or {}

local function isValidTarget(player, item)
	return player:isEquippedClothing(item) and not item:isHidden() and item:getType() ~= "NeuralHat"
end

function LSWardrobeContextMenu.setClothes(player, option)	
	local wornItems = player:getWornItems()
	local playerData = player:getModData()
	local lc = string.lower(option)
	playerData['LSClothes'][lc] = {}
	for n=1,31 do
		local val = n-1
		playerData['LSClothes'][lc..tostring(val)] = false
	end
	local wornNum
	for i=1,wornItems:size() do
		local val = i-1
		local wornItem = wornItems:get(val)
		local item = wornItem:getItem()
		if isValidTarget(player, item) then
			local itemFullType = item:getFullType()
			playerData['LSClothes'][lc..tostring(val)] = itemFullType
			table.insert(playerData['LSClothes'][lc], itemFullType)
			wornNum = val
			if val == 30 then break; end
		end
	end

	if not wornNum then return; end
	getSoundManager():playUISound("UI_Button_SELECT")
	player:Say(option.." set total:  " .. tostring(wornNum))

end
