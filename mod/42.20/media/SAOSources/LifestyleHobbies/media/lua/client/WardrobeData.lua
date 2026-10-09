
LSWardrobeContextMenu = LSWardrobeContextMenu or {}

LSWardrobeContextMenu.getWardrobeData = function()
	local playerObj = getPlayer()
	if not playerObj or not playerObj:hasModData() then return; end
	local playerData = playerObj:getModData()
	playerData['LSClothes'] = playerData['LSClothes'] or {}

	for n=1,#LSWardrobeContextMenu.changeOptions do
		local optionName = string.lower(LSWardrobeContextMenu.changeOptions[n])
		playerData['LSClothes'][optionName] = playerData['LSClothes'][optionName] or {}
		if #playerData['LSClothes'][optionName] == 0 then
			for i=1,31 do
				local val = i-1
				if playerData['LSClothes'][optionName..tostring(val)] then table.insert(playerData['LSClothes'][optionName], playerData['LSClothes'][optionName..tostring(val)]); end
			end
		end
	end
end

Events.OnCreatePlayer.Add(LSWardrobeContextMenu.getWardrobeData);
