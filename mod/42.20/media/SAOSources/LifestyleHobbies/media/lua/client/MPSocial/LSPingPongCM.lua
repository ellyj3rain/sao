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

LSPingPongCM = {}

local function getPlayersInArea(centerSqr, range, srcCharacter)
	if not isClient() then return false; end
	local playerIso = srcCharacter and srcCharacter:getOwnerPlayer()
	local outside, username
	if playerIso then outside, username = playerIso:isOutside(), playerIso:getUsername(); end
	local hasPlayers
	local playersList = {}
	for x = centerSqr:getX()-range,centerSqr:getX()+range do
		for y = centerSqr:getY()-range,centerSqr:getY()+range do
			local square = getCell():getGridSquare(x,y,centerSqr:getZ())
			if square then
				for i = 0,square:getMovingObjects():size()-1 do
					local moving = square:getMovingObjects():get(i);
					if instanceof(moving, "IsoPlayer") and (not moving.isAnimal or not moving:isAnimal()) and not moving:isInvisible() and (not playerIso or (
					moving:isOutside() == outside and playerIso:CanSee(moving) and playerIso:checkCanSeeClient(moving))) then
						local userKey = moving.getUsername and moving:getUsername()
						if userKey and not playersList[userKey] and (not username or userKey ~= username) then
							playersList[userKey] = moving
							hasPlayers = true
						end
					end
				end
			end
		end
	end
	return hasPlayers and playersList
end

local function improv_fakeRivalOption(parentMenu, character, obj, adjObj, movData, invSkill, spriteName)	
	local fR_option = parentMenu:addOption(getText("ContextMenu_Improvements_FakeRival"), character, LSPingPongCM.onImprovAction, obj, adjObj, spriteName, "fakeRival", 3, {["Lifestyle.upgradeWood"]=3,["Lifestyle.upgradeMechanical"]=1})
	local fR_tooltip = (movData.fakeRival and getText("Tooltip_Improvements_HasImp")) or
	(invSkill < 3 and getText("IGUI_CraftUI_RequiredSkills").." <SPACE>"..getText("UI_LSHS_Inventing").." ("..tostring(invSkill).."/3)")
	local hasParts
	if not fR_tooltip then
		local charInv = character:getInventory()
		hasParts = charInv:getNumberOfItem("Lifestyle.upgradeWood") >= 3 and charInv:getNumberOfItem("Lifestyle.upgradeMechanical") >= 1
		local woodIcon, woodName = LSUtil.getIconStrAndName("Lifestyle.upgradeWood")
		local mechIcon, mechName = LSUtil.getIconStrAndName("Lifestyle.upgradeMechanical")
		fR_tooltip = getText("IGUI_CraftUI_RequiredItems").." <LINE>"..woodIcon.." <SPACE>"..woodName.." - 3 <LINE>"..mechIcon.." <SPACE>"..mechName.." - 1"
	end
	fR_option.notAvailable = movData.fakeRival or invSkill < 3 or not hasParts
	fR_option.toolTip = LSUtil.getSimpleTooltip(fR_tooltip)
end

LSPingPongCM.adjSpritesTable = {
	['LS_Recreation_0'] = {"LS_Recreation_1", "E"},
	['LS_Recreation_1'] = {"LS_Recreation_0", "W"},
	['LS_Recreation_2'] = {"LS_Recreation_3", "S"},
	['LS_Recreation_3'] = {"LS_Recreation_2", "N"},
}

LSPingPongCM.getAdjObj = function(objSqr, spriteName)
	local adjSprite, dir = LSPingPongCM.adjSpritesTable[spriteName][1], LSPingPongCM.adjSpritesTable[spriteName][2]
	local adjSqrObjs = objSqr:getAdjacentSquare(IsoDirections[dir]):getObjects()
	for i=1,adjSqrObjs:size() do
		local adjObj = adjSqrObjs:get(i-1)
		local sprite = adjObj and adjObj:getSprite()
		local props = sprite and sprite:getProperties()
		if props and sprite:getName() ~= spriteName then
			local cName = props:has("CustomName") and props:get("CustomName")
			local gName = props:has("GroupName") and props:get("GroupName")
			if cName and cName == "Table" and gName and gName == "Ping Pong" then
				return adjObj
			end
		end
	end
	return false
end

local function getFakeRivalOverlay(spriteName)
	local t ={
	['LS_Recreation_0'] = {false, false, "LS_Recreation_4", false},
	['LS_Recreation_1'] = {false, false, false, "LS_Recreation_4"},
	['LS_Recreation_2'] = {false, false, "LS_Recreation_5", false},
	['LS_Recreation_3'] = {false, false, false, "LS_Recreation_5"},
	}
	return t[spriteName]
end

LSPingPongCM.doBuildMenu = function(player, context, worldobjects, obj, spriteName, customName, groupName, DebugBuildOption)
	if not LSUtil.isValidObj(obj, spriteName) then return; end
    local character = LSUtil.getValidPlayer(player)
	if LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character) then return; end
	local objSqr = obj:getSquare()
	local adjObj = LSPingPongCM.getAdjObj(objSqr, spriteName)
	if not adjObj then return; end
	local ogSubMenu = LSUtil.getObjContextMenu(context, spriteName)

	local charData = character:getModData()
	local reqUpdate = 0
	local objData, adjObjData = obj:getModData(), adjObj:getModData()
	if not objData.movableData then objData.movableData = {}; reqUpdate = reqUpdate+1; end
	if not adjObjData.movableData then adjObjData.movableData = {}; reqUpdate = reqUpdate+2; end
	local movData, adjMovData = objData.movableData, adjObjData.movableData
	movData.inUse = movData.inUse or false
	movData.fakeRival = movData.fakeRival or false
	adjMovData.inUse = adjMovData.inUse or false
	adjMovData.fakeRival = adjMovData.fakeRival or false
	if movData.inUse ~= adjMovData.inUse then movData.inUse = true; adjMovData.inUse = true; reqUpdate = 3; end
	if movData.fakeRival ~= adjMovData.fakeRival then movData.fakeRival = true; adjMovData.fakeRival = true; reqUpdate = 3; end

	if movData.fakeRival then
		local overlayInfo = getFakeRivalOverlay(spriteName)
		if overlayInfo then
			local wantObjOverlay, wantAdjObjOverlay = overlayInfo[3] or "", overlayInfo[4] or ""
			local curObjOverlay = (obj.getOverlaySprite and obj:getOverlaySprite() and obj:getOverlaySprite():getName()) or ""
			local curAdjObjOverlay = (adjObj.getOverlaySprite and adjObj:getOverlaySprite() and adjObj:getOverlaySprite():getName()) or ""
			if curObjOverlay ~= wantObjOverlay then LSUtil.modifyOverlaySprite(obj, wantObjOverlay); end
			if curAdjObjOverlay ~= wantAdjObjOverlay then LSUtil.modifyOverlaySprite(adjObj, wantAdjObjOverlay); end
		end
	end

	if reqUpdate > 0 and isClient() then -- 1 == obj, 2 == adjObj, 3 == both
		if reqUpdate ~= 2 then LSSync.transmitObjMovData(obj, false, movData); end
		if reqUpdate ~= 1 then LSSync.transmitObjMovData(adjObj, false, adjMovData); end
	end

	-- debug stuff
	if LSUtil.hasAdminRights() then
		local debugOption = ogSubMenu:addOption("Debug Tools")
		local debugSubMenu = ogSubMenu:getNew(ogSubMenu);
		context:addSubMenu(debugOption, debugSubMenu)
		--doDebugSubOptions(debugSubMenu, character, obj, movData, groupName)
	end

	-- table in use
	if movData.inUse or adjMovData.inUse then
		-- if its been more than one hour since inUse, check if user player is around the table !!
		local option = LSUtil.getDummyOption(ogSubMenu, getText("ContextMenu_LSMP_InUse"), " <RED>"..getText("Tooltip_LSMP_InUse"), getTexture('media/ui/okayNo_icon.png'), 'addOption', true)
		return
	end

	-- improvement tab
	if SandboxVars.Text.DividerArt then
		local invSkill = HiddenSkills.getLevel(character,"Inventing")
		local improvOption = ogSubMenu:addOption(getText("ContextMenu_Improvements_ImprovTab"))
		improvOption.iconTexture = getTexture('media/ui/maintenance_icon.png')
		local improvSubMenu = ogSubMenu:getNew(ogSubMenu)
		context:addSubMenu(improvOption, improvSubMenu)
		-- fakeRival
		improv_fakeRivalOption(improvSubMenu, character, obj, adjObj, movData, invSkill)
		--
	end
	--

	-- if client then get players around if table doesn't have fakeRival improvement
	local otherPlayers
	if not movData.fakeRival and not adjMovData.fakeRival then
		if not charData.LSCooldowns then charData.LSCooldowns = {}; end
		if not charData.LSCooldowns["InteractionSpam"] then charData.LSCooldowns["InteractionSpam"] = 0; end
		if charData.LSCooldowns["InteractionSpam"] >= 6 then
			-- player on cooldown due to spam
			local option = LSUtil.getDummyOption(ogSubMenu, getText("ContextMenu_LSMP_InvitePlay"), " <RED>"..getText("Tooltip_LSMP_CantInteract"), getTexture('media/ui/talkto_icon.png'), 'addOption', true)
			return
		else
			otherPlayers = getPlayersInArea(objSqr, 6, character)
			if not otherPlayers then
				-- table not in use, but no fakeRival improvement and either not isClient() or no other players around to ask to play with
				local option = LSUtil.getDummyOption(ogSubMenu, getText("ContextMenu_LSMP_InvitePlay"), " <RED>"..getText("Tooltip_LSMP_NoneNearby"), getTexture('media/ui/okayNo_icon.png'), 'addOption', true)
				return
			end
		end

		local socialOption = ogSubMenu:addOption(getText("ContextMenu_LSMP_InvitePlay"))
		socialOption.iconTexture = getTexture('media/ui/talkto_icon.png')
		local socialSubMenu = ogSubMenu:getNew(ogSubMenu)
		context:addSubMenu(socialOption, socialSubMenu)
			
		for k, v in pairs(otherPlayers) do
			local playerInfo = LSMPS.getOtherPlayerInfo(v)
			if playerInfo and not LSUtil.isCharBusy(v) and not LSUtil.isCharSitting(v) then
				local option = socialSubMenu:addOption(v:getDescriptor():getForename(), character, LSPingPongCM.onMPAction, v, obj, adjObj, spriteName)
			end
		end
	else -- table has fakeRival improvement
		local option = ogSubMenu:addOption(getText("ContextMenu_LSMP_InvitePlay"), character, LSPingPongCM.onAction, obj, adjObj, spriteName)
		option.iconTexture = getTexture('media/ui/talkto_icon.png')
	end


end

LSPingPongCM.customFace = {
	['LS_Recreation_0'] = "W",
	['LS_Recreation_1'] = "E",
	['LS_Recreation_2'] = "N",
	['LS_Recreation_3'] = "S",
}

LSPingPongCM.onImprovAction = function(character, obj, adjObj, spriteName, impKey, impLevel, itemList)
	if not LSUtil.isValidObj(obj, "PingPongA") or not LSUtil.isValidObj(adjObj, "PingPongB") or LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character) then return; end
	local movData = obj:getModData().movableData
	if movData.inUse then return; end
	local charInv = character:getInventory()
	for k, v in pairs(itemList) do
		if charInv:getNumberOfItem(k) < v then return; end
	end
	if LSUtil.walkToFront(character, obj) then
		local animArgs = {"Loot","LootPosition","Mid",false,false,"GeneratorRepair"} -- anim, animVariable 1, animVariable 2, setOverrideHandModels 1, setOverrideHandModels 2, sound
		local dataArgs = {[impKey]=true} -- data to add or change to movableData
		local spriteArgs = impKey == "fakeRival" and getFakeRivalOverlay(spriteName) -- obj sprite, adjObj sprite, obj overlay, adjObj overlay
		ISTimedActionQueue.add(LSInteractObject:new(character, obj, adjObj, {200*impLevel, itemList, animArgs, false, spriteArgs, movData, dataArgs}))
	end
end

local function getFacing(obj)
	local properties = obj:getSprite():getProperties()
	if properties:has("Facing") then return properties:get("Facing"); end
	return false
end

local function getFrontSqr(obj, customFace)
	local sqr = obj:getSquare()
	if not sqr then return false; end
	local facing = customFace or getFacing(obj)
	if not facing then return false; end
	local frontSqr = sqr:getAdjacentSquare(IsoDirections[facing])
	if not frontSqr then return false; end
	return frontSqr
end

LSPingPongCM.onMPAction = function(character, otherPlayer, obj, adjObj, spriteName)
	if not LSUtil.isValidObj(obj, spriteName) or not LSUtil.isValidObj(adjObj, spriteName) or
	LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character) or not otherPlayer or LSUtil.isCharBusy(otherPlayer) or LSUtil.isCharSitting(otherPlayer) then return; end
	if not LSMPS.isPlayerNearby(character, otherPlayer, 20) then return; end
	local movData = obj:getModData().movableData
	if movData.inUse then return; end
	if LSUtil.walkToFront(character, obj, false, LSPingPongCM.customFace[spriteName]) then
		local adjSpriteName = LSUtil.getObjSpriteName(adjObj)
		local srcSqr = getFrontSqr(obj, LSPingPongCM.customFace[spriteName])
		local targetSqr = getFrontSqr(adjObj, LSPingPongCM.customFace[adjSpriteName])
		if srcSqr and targetSqr then
			ISTimedActionQueue.add(LSWaitForInteractionObj:new(character, otherPlayer, obj, {srcSqr:getX(), srcSqr:getY(), srcSqr:getZ(),
																						targetSqr:getX(), targetSqr:getY(), targetSqr:getZ(),
																						adjObj:getX(), adjObj:getY(), adjObj:getZ(), adjSpriteName},
																						"TimedActions/LSPingPong",
																						{sN=spriteName, aSN=adjSpriteName},{"event","getPingPongKey"}))
		end
	end
end

LSPingPongCM.onAction = function(character, obj, adjObj, spriteName)
	if not LSUtil.isValidObj(obj, spriteName) or not LSUtil.isValidObj(adjObj, spriteName) or LSUtil.isCharBusy(character) or LSUtil.isCharSitting(character) then return; end

	local overlayInfo = getFakeRivalOverlay(spriteName)
	if overlayInfo and overlayInfo[3] then
		obj, adjObj = adjObj, obj
		spriteName = LSUtil.getObjSpriteName(obj)
	end
	local movData = obj:getModData().movableData
	if movData.inUse or not movData.fakeRival then return; end
	if LSUtil.walkToFront(character, obj, false, LSPingPongCM.customFace[spriteName]) then
		movData.inUse = true
		local formSelf = LSMPS.getPingPongForm(character)
		local formRival = ZombRandFloat(0.3, 0.7)
		local match = LSMPS.resolvePingPongMatch(formSelf, formRival)
		local adjSpriteName = LSUtil.getObjSpriteName(adjObj)
		ISTimedActionQueue.add(LSPingPong:new(character, nil, {{sN = spriteName, aSN = adjSpriteName, event = match}, true}))
	end
end