-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end

CLSInv = CLSInv or {}
local function updateInv(item, itemType)
	local data = item and item.getModData and item:getModData()
	local movData = data and data.movableData
	local invData = movData and movData['inventionData']
	local scriptArgs = invData and itemType and LSInventionDefs.ItemScript[itemType]
	
	if not scriptArgs or not itemType then return; end
	
	--item:setCustomName(true)
	if scriptArgs then
		for k, v in pairs(scriptArgs) do
			if invData[k] then
				if type(v) == "table" then
					for n=1,#v do
						if v[n] then
							LSUtil.setItemVal(item, 'get'..v[n], 'set'..v[n], invData[k][n])
						end
					end
				else
					LSUtil.setItemVal(item, 'get'..v, 'set'..v, invData[k])
				end
			end
		end
	end
end

CLSInv.UpdateInvScripts = function(character)
	local playerNum = character and character:getPlayerNum()
	if not playerNum then return; end

    local invWindow = getPlayerInventory(playerNum)
    local invContainer = invWindow and invWindow.inventoryPane and invWindow.inventoryPane.inventoryPage
    local lootWindow = getPlayerLoot(playerNum)
    local lootContainer = lootWindow and lootWindow.inventoryPane and lootWindow.inventoryPane.inventoryPage
	if not invContainer or not lootContainer or not invContainer.backpacks or not lootContainer.backpacks then return; end

	local containerList = ArrayList.new()
    for i,v in ipairs(invContainer.backpacks) do
		containerList:add(v.inventory);
    end
    for i,v in ipairs(lootContainer.backpacks) do
		containerList:add(v.inventory);
    end
	local id_cache = {}
	for i=0,containerList:size()-1 do
		local container = containerList:get(i);
		for x=0,container:getItems():size() - 1 do
			local item = container:getItems():get(x);
			if LSUtil.isValidInvItem(item) then
				local itemType = item.getType and item:getType()
				if itemType and LSInventionDefs.ItemScript[itemType] then
					local id = item:getID() or 0
					if not id_cache[id] then
						updateInv(item, itemType)
						if id and id ~= 0 then id_cache[id] = true; end
					end
				end
			end
		end
	end
end

HiddenSkills = HiddenSkills or {}

local function doNote(character, text, texture, addW)
	 -- Player, Text, Type, Texture, ScreenTime, ClosePermanent, InfoPanel, NoSpam, Texture Properties
	LSNoteMng.addToQueue(getCore():getScreenWidth()-(400+addW),(getCore():getScreenHeight()/5)-50,300+addW,50, {character, text, false, texture, 10, false, false, false, {6,10,30}})
end



HiddenSkills.onLvlUp_Inventing = function(character, level)
	local charData = character:getModData()
	charData.invData = charData.invData or {}
	InventionsMenu.workbench.resetInvCost(charData.invData)
	local noteText, noteTex = "", "media/ui/IW_icon.png"
	local levelStr = tostring(level)
	local addW = 0
	if level >= 10 then
		charData.invData['specialMax'] = charData.invData['specialMax'] or 1
		if not charData.invData['specialMax_lvl10'] then
			charData.invData['specialMax_lvl10'] = true
			charData.invData['specialMax'] = charData.invData['specialMax']+1
		end
		LSUtil.learnRecipes(character, {"ConvertPartsRareMech","ConvertPartsRareElec","ConvertPartsRarePlumb","ConvertPartsRareWood", "ConvertPartsMech","ConvertPartsElec","ConvertPartsPlumb","ConvertPartsWood"}) -- readd in case level jumped to 10 (admin)
		--noteTex = "media/ui/star_icon.png"
		noteText = getText("UI_LSHS_Inventing_Max",1)
	elseif level == 9 then
		LSUtil.learnRecipes(character, {"ConvertPartsMech","ConvertPartsElec","ConvertPartsPlumb","ConvertPartsWood"})
	elseif level == 1 or level == 5 then
		--addW = 100
	end

	if level > 0 then
		local customText = getText("UI_LSHS_Inventing_"..levelStr)
		if customText == "UI_LSHS_Inventing_"..levelStr then customText = ""; end
		--local starTex = " <IMAGE:media/ui/star_icon.png,16,16>"
		--local maxLevel = (level == 10 and " <SPACE>"..starTex) or ""
		noteText = " <RGB:1,1,1><CENTRE>"..getText("UI_LSHS_Inventing")..": <SPACE><RGB:1,1,0.7>"..getText("IGUI_PlayerStats_Level").." "..levelStr..
		" <LINE><TEXT><RGB:1,1,1>"..noteText..customText..getText("UI_LSHS_Inventing_General")

		--getSoundManager():playUISound("UI_Note_Appear")
		doNote(character, noteText, noteTex, addW)
	end

	if isClient() then sendClientCommand(character, "LS", "SavePlayerData", {charData}); end
end