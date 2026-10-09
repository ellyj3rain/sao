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

require 'ISUI/ISWorldObjectContextMenu'

local function LookForTP(thisPlayer)

	local TPTypes = require "Properties/TPTypes"
	local containerList = ArrayList.new();
	local playerNum = thisPlayer and thisPlayer:getPlayerNum() or -1
	local ToiletPaper
	local TPQuality = "bad"
    for i,v in ipairs(getPlayerInventory(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end
    for i,v in ipairs(getPlayerLoot(playerNum).inventoryPane.inventoryPage.backpacks) do
		containerList:add(v.inventory);
    end

--	if #containerList > 0 then
--		for i,v in ipairs(containerList:getItems()) do
		for i=0,containerList:size()-1 do
			local container = containerList:get(i);
			for x=0,container:getItems():size() - 1 do
				local containerItem = container:getItems():get(x);
				
				for k,v in pairs(TPTypes) do

					if (containerItem:getFullType() == v.name) and not ToiletPaper then
						ToiletPaper = containerItem
						TPQuality = v.category
						break
					elseif (containerItem:getFullType() == v.name) and (TPQuality == "bad") and (v.category ~= "bad") then
						ToiletPaper = containerItem
						TPQuality = v.category
						break
					elseif (containerItem:getFullType() == v.name) and (TPQuality == "normal") and (v.category == "good") then
						ToiletPaper = containerItem
						TPQuality = v.category
						break
					end
				end
				if ToiletPaper and (TPQuality == "good") then
					break
				end
			end
			if ToiletPaper and (TPQuality == "good") then
				break
			end
		end

	if not ToiletPaper then
		return false
	else
		return ToiletPaper, TPQuality
	end
end

local function CheckTPTexture(toiletPaperQuality)

	local Icon = getTexture('media/ui/toiletNOPAPER_icon.png')

	if toiletPaperQuality == "bad" then
		Icon = getTexture('media/ui/toiletBAD_icon.png')
	elseif toiletPaperQuality == "normal" then
		Icon = getTexture('media/ui/toiletRAGS_icon.png')
	elseif toiletPaperQuality == "good" then
		Icon = getTexture('media/ui/toilet_icon.png')
	end
	return Icon

end

local function onDoToiletGround(worldobjects, thisPlayer, toiletPaper, toiletPaperQuality)

	if thisPlayer:isSneaking() then thisPlayer:setSneaking(false); end

	local LSUseToiletGround = require "TimedActions/LSUseToiletGround"
    ISTimedActionQueue.add(LSUseToiletGround:new(thisPlayer, toiletPaper, toiletPaperQuality))
end

ToiletGroundContextMenu = {};
ToiletGroundContextMenu.doBuildMenu = function(player, context, worldobjects, DebugBuildOption)

    local thisPlayer = getSpecificPlayer(player)

	if not thisPlayer then return; end
	if thisPlayer:getVehicle() or thisPlayer:isSitOnGround() or thisPlayer:isSittingOnFurniture() then return; end
	--if thisPlayer:isSneaking() then return; end
	
	local playerdata
	
	if thisPlayer:hasModData() then
		playerdata = thisPlayer:getModData()
	else
	return; end
	
	if playerdata.IsDoingToilet then return; end

	local toiletPaper, toiletPaperQuality = LookForTP(thisPlayer)
	local TPIcon = getTexture('media/ui/toiletNOPAPER_icon.png')
	if toiletPaper and toiletPaperQuality then
		TPIcon = CheckTPTexture(toiletPaperQuality)
	end

	
	--if playerdata.LSMoodles["BladderNeed"].Value >= 0.6 or ((playerdata.LSMoodles["BladderNeed"].Value >= 0.4) and (thisPlayer:hasTrait(CharacterTrait.OUTDOORSMAN) or thisPlayer:hasTrait(CharacterTrait.SLOPPY) or thisPlayer:hasTrait(CharacterTrait.WEAK_STOMACH))) then
	if playerdata.LSMoodles["BladderNeed"].Value >= 0.4 then
		local toiletgroundoption = context:addOptionOnTop(getText("ContextMenu_Toilet_Ground"), worldobjects, onDoToiletGround, thisPlayer, toiletPaper, toiletPaperQuality);
		toiletgroundoption.iconTexture = TPIcon
	end
end
