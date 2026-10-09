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
LSHygiene = LSHygiene or {}
LSHygiene.TF = {};
LSHygiene.TF.outhouseAreas = {}

local function isValid(character)
	return LSUtil.getValidCharacter(character)
end

local function wantsToFlush(character)
	local odds = ZombRand(100)+1
	if character:hasTrait(CharacterTrait.SLOPPY) then odds = math.ceil(odds*2);
	elseif character:hasTrait(CharacterTrait.TIDY) then odds = math.floor(odds*0.8);
	elseif character:hasTrait(CharacterTrait.CLEANFREAK) then return true; end

	return odds <= 75
end

local function getToiletSound(objType)
	local soundLib = require("Hygiene/Tracks/ToiletSounds")
	local available = {}
	for k,v in pairs(soundLib) do
		if v.category == objType then
			table.insert(available, v)
		end
	end
	if not available or #available == 0 then return false; end
	return available[ZombRand(#available)+1]
end

LSHygiene.TF.isInOuthouseArea = function(x, y, SAreaData)
	local range = SandboxVars.LSHygiene.OuthouseRange or 10
	local areaTable = SAreaData or LSHygiene.TF.outhouseAreas
	for n=1,#areaTable do
		local areaX, areaY = areaTable[n][1], areaTable[n][2]
		if x >= areaX-range and x <= areaX+range and y >= areaY-range and y <= areaY+range then
			return true
		end
	end
	return false
end

local instance_outhouseloaded
local function loadOuthouseTable()
	if instance_outhouseloaded then return; end
	local lsData = ModData.getOrCreate("LSDATA")
	if not lsData or not lsData["SO"] or not lsData["SO"]["OUTHOUSEAREAS"] then LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - loadOuthouseTable - FAILED to get OUTHOUSEAREAS"); return; end
	LSHygiene.TF.outhouseAreas = LSUtil.deepCopy(lsData["SO"]["OUTHOUSEAREAS"])
	instance_outhouseloaded = true
end

if not isServer() or isClient() then Events.OnGameStart.Add(loadOuthouseTable); end

LSHygiene.TF.getFlushSound = function(groupName)
	local sounds = {
		["Fancy"] = "Toilet_Flush_Fancy",
		["Low"] = "Toilet_Flush_Cheap",
		["Hanging"] = "Toilet_Flush_Hanging",
		["Chemical"] = "Toilet_Flush_Hanging",
	}
	return sounds[groupName]
end

LSHygiene.TF.getWaterUsage = function(groupName)
	local waterUse = {
		["Fancy"] = 5,
		["Low"] = 10,
		["Hanging"] = 5,
	}
	return waterUse[groupName]
end

LSHygiene.TF.getDirtySprites = function(obj, name)
	local spriteName = name or (obj and obj.getSprite and obj:getSprite():getName())
	local spriteTable = LSHygiene.DS.getFromSpriteName(spriteName)
	if not spriteTable then return false; end
	return spriteTable[1], spriteTable[2], spriteTable[3]
	--local facing = obj and obj:getSprite():getProperties():get("Facing")
	--if not facing or not t[toiletType] or not t[toiletType][facing] then return false, false, false; end
	--return t[toiletType][facing][1], t[toiletType][facing][2], t[toiletType][facing][3]
end

--[[
LSHygiene.TF.getDirtySprites = function(obj, toiletType)
	local t = {
		['Fancy'] = {
			['S'] = {"LS_Misc_0","LS_Misc_8","LS_Misc_16"},
			['E'] = {"LS_Misc_1","LS_Misc_9","LS_Misc_17"},
			['W'] = {"LS_Misc_2","LS_Misc_10","LS_Misc_18"},
			['N'] = {"LS_Misc_3","LS_Misc_11","LS_Misc_19"},
		},
		['Low'] = {
			['S'] = {"LS_Misc_4","LS_Misc_12","LS_Misc_20"},
			['E'] = {"LS_Misc_5","LS_Misc_13","LS_Misc_21"},
			['W'] = {"LS_Misc_6","LS_Misc_14","LS_Misc_22"},
			['N'] = {"LS_Misc_7","LS_Misc_15","LS_Misc_23"},
		},	
	}
	local spriteName = obj and obj.getSprite and obj:getSprite():getName()
	return spriteName
	--local facing = obj and obj:getSprite():getProperties():get("Facing")
	--if not facing or not t[toiletType] or not t[toiletType][facing] then return false, false, false; end
	--return t[toiletType][facing][1], t[toiletType][facing][2], t[toiletType][facing][3]
end
]]--

LSHygiene.TF.onAction = function(character, obj, args) -- objType, waterUse, Flush, SeatUp, SeatDown, category, ignoreWalk, customFace
	LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.onAction - start")
	local walkAction
	if not args[7] then
		LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.onAction - not ignore walk")
		if obj and LSUtil.isValidObj(obj, "none") then
			LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.onAction - obj is valid")
			--walkAction = LSUtil.walkToFront(character, obj, 'isSitOnGround', args[8])
			walkAction = LSUtil.walkToFront(character, obj, 'isSittingOnFurniture')
		else
			LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.onAction - obj is not valid")
			local sqr = character:getSquare()
			local newSqr = LSUtil.srqGetClosest({sqr:getS(),sqr:getN(),sqr:getE(),sqr:getW()}, character)
			walkAction = LSUtil.walkToSqr(character, newSqr)
		end
	end
	if args[6] == "IsUse" then
		LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.onAction - IsUse, calling timed action")
		local dirtSprite, dirtSprite2, dirtSprite3 = LSHygiene.TF.getDirtySprites(obj)
		local action = require "TimedActions/LSUseToilet"
		ISTimedActionQueue.add(action:new(character, obj, {args[1], args[4], args[5], dirtSprite, dirtSprite2, dirtSprite3}))
	elseif args[6] == "IsFlush" and wantsToFlush(character) then
		LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.onAction - IsFlush, calling timed action")
		local action = LSFlushToilet:new(character, obj, args[1], not args[7])
		if not args[7] then
			ISTimedActionQueue.addAfter(walkAction, action)
		else
			ISTimedActionQueue.add(action)
		end
	else
		LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.onAction - no valid category found")
	end
end

LSHygiene.TF.doFlush = function(character, obj, objType, waterUse, ignoreWalk, customFace)
	LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.doFlush - start")
	if not isValid(character) then return; end
	--local sound = getToiletSound(objType)
	local sound = LSHygiene.Sounds.getRandomFromFile(objType, 'ToiletSounds')
	if not sound then LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.doFlush - no valid sound found, stopping"); return; end
	LSUtil.debugPrint("shared/Hygiene/ToiletFunctions.lua - LSHygiene.TF.doFlush - calling LSHygiene.TF.onAction")
	LSHygiene.TF.onAction(character, obj, {objType, waterUse, sound.isflush, sound.seatUp, sound.seatDown, "IsFlush", ignoreWalk, customFace})
end

LSHygiene.TF.doDisturbed = function(character, targetX, targetY, obj)
	if not LSUtil.getValidCharacter(character) then return; end
	if obj and LSUtil.isValidObj(obj, "none") and not LSUtil.walkToFront(character, obj) then return; end
	ISTimedActionQueue.add(ShooOther:new(character, targetX, targetY))
end

LSHygiene.TF.useTP = function(character, item, itemCont)
	if not item then LSUtil.debugPrint("LSUseToilet - no tp"); return; end
	local fullType = item.getFullType and item:getFullType()
	if not fullType then return; end
	local charInv = character:getInventory()
	LSUtil.debugPrint("LSUseToilet - has tp")
	if fullType == "Base.ToiletPaper" or fullType == "Base.Tissue" then
		LSUtil.useItem(item, character)
	else
		LSUtil.debugPrint("LSUseToilet - not TP and not tissue")
		charInv:setDrawDirty(true)
		if (fullType == "Base.RippedSheets" or fullType == "Base.AlcoholRippedSheets") then
			LSUtil.debugPrint("LSUseToilet - is ripped sheet, trying to add dirty sheet")
			if isClient() then
				sendClientCommand(character, "LS", "AddItemToPlayer", {"Base.RippedSheetsDirty", 1})
			else
				charInv:AddItem("Base.RippedSheetsDirty")
			end
		end
		LSUtil.debugPrint("LSUseToilet - trying to remove rag")
		if isClient() then
			sendClientCommand(character, "LS", "RemoveItemFromPlayer", {fullType, 1})
		else
			charInv:DoRemoveItem(item)
			item = nil
			getPlayerInventory(character:getPlayerNum()):refreshBackpacks()	
		end
	end
	--local containsItem = charInv:contains(item)
	if item and itemCont then
		TransferHelper.transferItem(character, item, charInv, itemCont, character:getSquare(), false)
	else
		LSUtil.debugPrint("LSUseToilet - no toiletpaperItem or transfer fail")
		if not itemCont then LSUtil.debugPrint("LSUseToilet - not tpContainer"); end
		if not containsItem then LSUtil.debugPrint("LSUseToilet - not containsItem"); end
	end
end

LSHygiene.TF.puddleList = {"LS_HScraps_DirtPuddle_0","LS_HScraps_DirtPuddle_1","LS_HScraps_DirtPuddle_2","LS_HScraps_DirtPuddle_3","LS_HScraps_DirtPuddle_4",
	"LS_HScraps_DirtPuddle_5","LS_HScraps_DirtPuddle_6","LS_HScraps_DirtPuddle_7"}

LSHygiene.TF.doDirtPuddle = function(square)
	if not square or square:isOutside() then LSUtil.debugPrint("doDirtPuddle - not square or squase is outside"); return; end
	local dirtSprite = LSHygiene.TF.puddleList[ZombRand(#LSHygiene.TF.puddleList)+1]
	if isClient() then
		LSLitter.createDirtPuddle(square, dirtSprite)
	else
		LSAddLitter(square:getX(), square:getY(), square:getZ(), 2, dirtSprite)
	end
end