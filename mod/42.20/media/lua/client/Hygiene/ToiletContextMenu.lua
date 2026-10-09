-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
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

require "Properties/Player/CleaningSkill"

ToiletContextMenu = {};

local function predicateNotFull(item)
    return item:getCurrentUsesFloat() < 1
end

local function StringStartWith(String,Start)
	return string.sub(String, 1, string.len(Start)) == Start;
end

local function ItemHasCleaningLiquid(item)
	if not item then return false; end
	local fluidContainer = item:getFluidContainer()
	local primaryFluid = fluidContainer and fluidContainer:getPrimaryFluid()
	return fluidContainer and fluidContainer:getAmount() > 0 and primaryFluid and primaryFluid:getFluidTypeString() == "CleaningLiquid"
end

ToiletContextMenu.LookForTP = function(thisPlayer)

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


ToiletContextMenu.CheckTPTexture = function(toiletPaperQuality)

	local Icon = getTexture('media/ui/toiletNOPAPER_icon.png')
	local Icon2 = getTexture('media/ui/toiletRelaxNOPAPER_icon.png')

	if toiletPaperQuality == "bad" then
		Icon = getTexture('media/ui/toiletBAD_icon.png')
		Icon2 = getTexture('media/ui/toiletRelaxBAD_icon.png')
	elseif toiletPaperQuality == "normal" then
		Icon = getTexture('media/ui/toiletRAGS_icon.png')
		Icon2 = getTexture('media/ui/toiletRelaxRAGS_icon.png')
	elseif toiletPaperQuality == "good" then
		Icon = getTexture('media/ui/toilet_icon.png')
		Icon2 = getTexture('media/ui/toiletRelax_icon.png')
	end
	return Icon, Icon2

end

ToiletContextMenu.debug_uses = function(obj, movData, newUses)
	movData['uses'] = newUses
	if isClient() then LSSync.transmitObjMovData(obj, false, movData); end
end

ToiletContextMenu.debug_reset = function(obj, movData)
	local args = {"condition","dirtyLevel","uses","needFlush","isClogged","cloggedTotal"}
	for n=1,#args do
		local arg = args[n]
		if movData[arg] then movData[arg] = false; end
	end
	if isClient() then LSSync.transmitObjMovData(obj, false, movData); end
	local currentOverlay = obj.getOverlaySprite and obj:getOverlaySprite()
	if currentOverlay and currentOverlay ~= "" then
		if isClient() then
			sendClientCommand("LS", "ModifyOverlaySprite", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()},""})
		else
			obj:setOverlaySprite("", false)
		end
	end
end

ToiletContextMenu.debug_clean = function(obj, movData, lvl, cnd, dirtyOverlays)
	if movData['dirtyLevel'] == lvl then return; end -- at same level
	movData['dirtyLevel'] = lvl
	movData['condition'] = cnd
	if isClient() then LSSync.transmitObjMovData(obj, false, movData); end
	local currentOverlay = obj.getOverlaySprite and obj:getOverlaySprite()
	local updateOverlay
	local isDirty = movData.dirtyLevel > 0
	if isDirty and (not currentOverlay or currentOverlay ~= dirtyOverlays[movData.dirtyLevel]) then
		updateOverlay = dirtyOverlays[movData.dirtyLevel]
	elseif movData.dirtyLevel == 0 and currentOverlay and currentOverlay ~= "" then
		updateOverlay = ""
	end
	if updateOverlay then
		if isClient() then
			sendClientCommand("LS", "ModifyOverlaySprite", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()},updateOverlay})
		else
			obj:setOverlaySprite(updateOverlay, false)
		end
	end
end

local function doDebugSubOptions(subMenu, character, obj, movData, groupName, dirtyOverlays)
	-- reset
	local resetOption = subMenu:addOption("Reset",obj,ToiletContextMenu.debug_reset, movData)
	-- max dirty
	local dirtyOption = subMenu:addOption("Max Dirty",obj,ToiletContextMenu.debug_clean,movData,3,100,dirtyOverlays)
	-- clean
	local cleanOption = subMenu:addOption("Clean",obj,ToiletContextMenu.debug_clean,movData,0,0,dirtyOverlays)
	-- uses
	if movData.uses then
		local noUses = movData.uses <= 0
		local cleanOption = subMenu:addOption((noUses and "Reset uses") or "Drain uses",obj,ToiletContextMenu.debug_uses,movData,(not noUses and 0) or (groupName == "Chemical" and 30) or 100)
	end
end

local function getObjContextMenu(context, objName, objTex)
	local subMenu
    for i = 1, #context.options do
        local option = context.options[i]
        if option and option.name and option.name == objName then
			if option.subOption ~= nil then subMenu = context:getSubMenu(option.subOption); end
			if not subMenu then
				subMenu = ISContextMenu:getNew(context)
				context:addSubMenu(option, subMenu)
            end
			return subMenu
		end
    end
	local option = context:addOptionOnTop(objName)
	option.iconTexture = objTex
	subMenu = ISContextMenu:getNew(context)
	context:addSubMenu(option, subMenu)
    return subMenu
end

ToiletContextMenu.doBuildMenu = function(player, context, worldobjects, obj, spriteName, customName, groupName, DebugBuildOption)
	if not LSUtil.isValidObj(obj, spriteName) then return; end
    local character = LSUtil.getValidPlayer(player)
	if LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character) then return; end

	local objTex, objName = LSUtil.getObjTexAndText(spriteName)
	--local invName = LSUtil.getMoveableDisplayName("Invention", inv, customName, groupName)
	local ogSubMenu = getObjContextMenu(context, objName, objTex)

	local charData = character:getModData()
	charData.bathroomNeed = charData.bathroomNeed or 0
	local reqUpdate
	local objData = obj:getModData()
	if not objData.movableData then objData.movableData = {}; reqUpdate = true; end
	local movData = objData.movableData
	if not movData.dirtyLevel or not movData.condition then reqUpdate = true; end
	movData.dirtyLevel = movData.dirtyLevel or 0
	movData.condition = movData.condition or 0

	local maxUses = (groupName == "Chemical" and 30) or (groupName == "Wooden" and 100)
	if maxUses and not movData.uses then movData.uses = maxUses; end
	local canRefill = groupName == "Chemical" and movData.uses <= 0

	local dirtyOverlays = LSHygiene.DS.Toilets[spriteName]
	if not dirtyOverlays then return; end
	local currentOverlay = obj.getOverlaySprite and obj:getOverlaySprite()
	local updateOverlay
	local isDirty = movData.dirtyLevel > 0
	if isDirty and (not currentOverlay or currentOverlay ~= dirtyOverlays[movData.dirtyLevel]) then
		updateOverlay = dirtyOverlays[movData.dirtyLevel]
	elseif movData.dirtyLevel == 0 and currentOverlay and currentOverlay ~= "" then
		updateOverlay = ""
	end
	
	if updateOverlay then
		if isClient() then
			sendClientCommand("LS", "ModifyOverlaySprite", {{obj:getX(),obj:getY(),obj:getZ(),obj:getSprite():getName()},updateOverlay})
		else
			obj:setOverlaySprite(updateOverlay, false)
		end
		currentOverlay = updateOverlay
	end

	if reqUpdate and isClient() then LSSync.transmitObjMovData(obj, false, movData); end

	-- debug stuff
	if LSUtil.hasAdminRights() then
		local debugOption = ogSubMenu:addOption("Debug Tools")
		local debugSubMenu = ogSubMenu:getNew(ogSubMenu);
		context:addSubMenu(debugOption, debugSubMenu)
		doDebugSubOptions(debugSubMenu, character, obj, movData, groupName, dirtyOverlays)
	end
	-- clean and unclog cleaning items
	local clogged = movData.isClogged and movData.isClogged >= 0
	local cleaningItems
	if isDirty or clogged then
		cleaningItems = {}
		local it = character:getInventory():getItems()
		for j = 0, it:size()-1 do
			local item = it:get(j)
			local itemType = item and item.getType and item:getType()
			if itemType then
				if isDirty and not cleaningItems[1] and itemType == "Sponge" then
					cleaningItems[1] = item
				elseif isDirty and not cleaningItems[2] and LSUtil.itemHasFluid(item, "CleaningLiquid", false, true) then
					cleaningItems[2] = item
				elseif clogged and not cleaningItems[3] and itemType == "Plunger" and not item:isBroken() then
					cleaningItems[3] = item
				elseif canRefill and not cleaningItems[4] and LSUtil.itemHasFluid(item, "Bleach", 1, true) then
					cleaningItems[4] = item
				end
			end
			if (not isDirty or (cleaningItems[1] and cleaningItems[2])) and (not clogged or cleaningItems[3]) and (not canRefill or cleaningItems[4]) then
				break
			end
		end
	end
	-- get unclog option
	if clogged then -- we only show the unclog option if the toilet is clogged, even if the player lacks a plunger
			local unclogVal, rgbColor
			if movData.cloggedTotal then -- if somehow toilet is missing cloggedTotal data (old saves) then we dont show the progress tooltip
				unclogVal = 0
				if movData.isClogged > 0 then -- isClogged is not how much was worked already, but how much is still missing to finish - 0 means toilet is clogged but unclogging hasn't started yet
					local realProgress = movData.cloggedTotal - movData.isClogged
					if realProgress > 0 then unclogVal = LSUtil.getPercentage(movData.cloggedTotal,realProgress,2); else unclogVal = false; end -- if realProgress is somehow negative we don't show the tooltip
				end
				if unclogVal then
					if unclogVal < 30 then
						rgbColor = " <RGB:1,0,0>"
					elseif unclogVal < 60 then
						rgbColor = " <RGB:1,1,0>"
					else
						rgbColor = " <RGB:0,1,0>"
					end
				end
			end
			
			local unclogDuration = movData.isClogged > 0 and movData.isClogged
			local unclogOption = ogSubMenu:addOptionOnTop(getText("ContextMenu_Toilet_Unclog"),character,ToiletContextMenu.onAction,obj,groupName,spriteName,unclogDuration,cleaningItems,"IsUnclog")
			local canUnclog = cleaningItems and cleaningItems[3]
			local tex = (canUnclog and 'unclog_icon') or 'unclogNO_icon'
			unclogOption.notAvailable = not canUnclog
			unclogOption.iconTexture = getTexture('media/ui/'..tex..'.png')
			local tooltipText = (not canUnclog and getText("Tooltip_Toilet_UnclogNoItem")) or (unclogVal and getText("Tooltip_Toilet_UnclogProgress")..rgbColor..unclogVal.." <RGB:1,1,1> / 100%%")
			if tooltipText then unclogOption.toolTip = LSUtil.getSimpleTooltip(tooltipText); end
	end
		-- get cleaning option (always apppears, even when not dirty)
	local cloggedBlock = clogged and not SandboxVars.LSHygiene.CleanClogged
	if not isDirty or cloggedBlock then
		local notDirtyTxt = (cloggedBlock and "Fixture_CleanClogged") or "Toilet_IsClean"
		local option = LSUtil.getDummyOption(ogSubMenu, getText("ContextMenu_Toilet_Clean"), " <RED>"..getText("Tooltip_"..notDirtyTxt), getTexture('media/ui/cleanNO_icon.png'), 'addOption', true)
	else
			local cleanRate = LSCleaning.getCleaningTime(character, {"Bathroom", movData.dirtyLevel, false})
			local cleanOption = ogSubMenu:addOptionOnTop(getText("ContextMenu_Toilet_Clean"),character,ToiletContextMenu.onAction,obj,groupName,spriteName,cleanRate,cleaningItems,"IsClean")
			local canClean = cleaningItems and cleaningItems[1] and cleaningItems[2]
			local tex = (canClean and 'clean_icon') or 'cleanNO_icon'
			cleanOption.notAvailable = not canClean
			cleanOption.iconTexture = getTexture('media/ui/'..tex..'.png')
			if not canClean then cleanOption.toolTip = LSUtil.getSimpleTooltip(getText("Tooltip_Toilet_CleanNoItem")); end
	end

	local waterUsage = LSHygiene.TF.getWaterUsage(groupName)
	-- common toilet without water
	if waterUsage and not LSUtil.objHasWater(obj, waterUsage) then
		local option = LSUtil.getDummyOption(ogSubMenu, getText("ContextMenu_Toilet_NoWater"), " <RED>"..getText("Tooltip_Toilet_NoWater"), getTexture('media/ui/toiletNO_icon.png'), 'addOption', true)
		return
	end
	
	-- outhouse checks
	if groupName == "Wooden" then
		if movData.uses < 1 then -- without uses, can't be used anymore
			local range = SandboxVars.LSHygiene.OuthouseRange or 10
			local option = LSUtil.getDummyOption(ogSubMenu, getText("ContextMenu_Toilet_Wooden_NoUses"), " <RED>"..getText("Tooltip_Toilet_Wooden_NoUses",range*2), getTexture('media/ui/toiletNO_icon.png'), 'addOption', true)
			return
		elseif movData.uses == 100 and LSHygiene.TF.isInOuthouseArea(obj:getX(), obj:getY()) then -- new outhouse in occupied outhouse area (maxUses < 100)
			local option = LSUtil.getDummyOption(ogSubMenu, getText("ContextMenu_Toilet_Wooden_Occupied"), " <RED>"..getText("Tooltip_Toilet_Wooden_Occupied"), getTexture('media/ui/toiletNO_icon.png'), 'addOption', true)
			return
		end
	end

	-- end of returning conditions

	-- outhouse requires nothing and has a lot of uses, but once it reaches 0 the pit is full and cant be emptied, making the area invalid for new outhouses; can't clog
	-- chemical - once uses reach 0 must be emptied (requires empty bucket, returns buckect filled with tainted water), then after emptied requires a full litre of pure bleach (cant be mixed) to get max uses again; can all
	-- be done with movData to side-step the fluid system; can get clogged

	-- needs flushing
	local useCommand = "IsUse"
	if movData.needFlush then
		local flushOption = ogSubMenu:addOptionOnTop(getText("ContextMenu_Toilet_Flush"),character,ToiletContextMenu.onAction,obj,groupName,spriteName,nil,nil,"IsFlush")
		local tex = (clogged and 'gearsBAD_icon') or 'gears_icon'
		flushOption.iconTexture = getTexture('media/ui/'..tex..'.png')
		if not character:hasTrait(CharacterTrait.SLOPPY) then
			useCommand = "IsFlushAndUse"
		end
	end
	
	-- get use option
	if charData.LSMoodles["BladderNeed"].Value < 0.2 or (groupName == "Hanging" and character:isFemale()) then return; end -- we hide the option until first moodle level, unless its urinal and character is woman
	local canUse = not clogged and (not movData.uses or movData.uses > 0)
	local tpQuality, TPIcon, TPIcon2
	if canUse then
		if not cleaningItems then cleaningItems = {}; end
		-------------------TOILET PAPER--------- rewrite this code later
		cleaningItems[4], tpQuality = ToiletContextMenu.LookForTP(character)
		TPIcon = getTexture('media/ui/toiletNOPAPER_icon.png')
		TPIcon2 = getTexture('media/ui/toiletRelaxNOPAPER_icon.png')
		if cleaningItems[4] and tpQuality then
			TPIcon, TPIcon2 = ToiletContextMenu.CheckTPTexture(tpQuality)
		end
		----------
	end
	local useOption = ogSubMenu:addOptionOnTop(getText("ContextMenu_Toilet_Use"),character,ToiletContextMenu.onAction,obj,groupName,spriteName,tpQuality,cleaningItems,useCommand)
	useOption.iconTexture = (not canUse and getTexture('media/ui/toiletNO_icon.png')) or TPIcon
	useOption.notAvailable = not canUse
	local useTooltipText = (clogged and getText("Tooltip_Toilet_Clogged")) or (movData.uses and movData.uses <= 0 and getText("Tooltip_Toilet_"..groupName.."_NoUses"))
	if not useTooltipText and movData.uses then useTooltipText = getText("Tooltip_Toilet_Uses",movData.uses); end
	if useTooltipText then useOption.toolTip = LSUtil.getSimpleTooltip(useTooltipText); end
	
	-- get refill option
	if canRefill then
		local option = ogSubMenu:addOptionOnTop(getText("ContextMenu_Toilet_Refill"),character,ToiletContextMenu.onAction,obj,groupName,spriteName,300,cleaningItems,"IsRefill")
		local tex = (not cleaningItems[4] and 'noWater_icon') or 'gears_icon'
		option.iconTexture = getTexture('media/ui/'..tex..'.png')
		option.notAvailable = not cleaningItems[4]
		option.toolTip = LSUtil.getSimpleTooltip(getText("Tooltip_Toilet_Refill",1,Translator.getFluidText("Bleach")))
	end
end

ToiletContextMenu.sitOnToilet = function(character, thisObject, thisObjectType)
	local action
	ActionHelper.onRest(thisObject, character, action)
end

ToiletContextMenu.onAction = function(character, obj, groupName, spriteName, duration, items, command)
	if not command or not LSUtil.isValidObj(obj, spriteName) or LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character) then return; end
	if LSUtil.walkToFront(character, obj) then
		local movData = obj:getModData().movableData
		if command == "IsClean" then
			ISTimedActionQueue.add(LSCleanObject:new(character, obj, false, spriteName, duration, movData, items[1], items[2]))
			return
		end
		if command == "IsRefill" then
			if not items[4] or not items[4]:isInPlayerInventory() or not LSUtil.itemHasFluid(items[4], "Bleach", 1, true) then return; end
			local animArgs = {"Pour","PourType","Bucket","Bucket",false,"GetWaterFromDispenserMetalMedium"} -- anim, animVariable 1, animVariable 2, setOverrideHandModels 1, setOverrideHandModels 2, sound
			local fluidArgs = {items[4], "Bleach", 1, "Remove", true, items[4]:getID()} -- fluid container item, fluid type, amount, add or remove, is primary
			local dataArgs = {["uses"]=30} -- data to add or change to movableData
			ISTimedActionQueue.add(LSInteractObject:new(character, obj, false, {duration, false, animArgs, fluidArgs, false, movData, dataArgs}))
			return
		end
		if command == "IsUnclog" then
			if not items[3]:isEquipped() then
				ISTimedActionQueue.add(ISEquipWeaponAction:new(character, items[3], 50, true, false))
			end
			if not duration then
				duration = LSCleaning.getCleaningTime(character, {"Unclog", false, false})
				movData.cloggedTotal = duration
			end
			local LSUnclogToilet = require "TimedActions/LSUnclogToilet"
			ISTimedActionQueue.add(LSUnclogToilet:new(character, obj, groupName, items[3], duration))
			return
		end
		if command == "IsFlush" or command == "IsFlushAndUse" then
			ISTimedActionQueue.add(LSFlushToilet:new(character, obj, groupName))
			if command == "IsFlush" then return; end
		end
		if command == "IsUse" or command == "IsFlushAndUse" then
			if movData.uses and movData.uses <= 0 then return; end
			local LSUseToilet = require "TimedActions/LSUseToilet"
			local useAction = LSUseToilet:new(character, obj, groupName, duration, spriteName, items[4]) -- duration is tpQuality
			if groupName ~= "Hanging" then
				ActionHelper.onRest(obj, character, useAction)
			else
				ISTimedActionQueue.add(useAction)
			end
			return
		end
	end
end