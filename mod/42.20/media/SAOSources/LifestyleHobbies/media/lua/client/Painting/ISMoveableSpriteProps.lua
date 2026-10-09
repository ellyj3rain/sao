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

require 'Moveables/ISMoveableSpriteProps';

local function setHighlightedColors()
	-- not vanilla, required as some mods override the ISMoveableSpriteProps table, erasing all it's contents
	if not ISMoveableSpriteProps.bhc then ISMoveableSpriteProps.bhc = getCore():getBadHighlitedColor(); end
	if not ISMoveableSpriteProps.ghc then ISMoveableSpriteProps.ghc = getCore():getGoodHighlitedColor(); end
end

local function getbeautyRGB(quality)
	if quality == "IGUI_PaintingQuality_Good" then return 0,128,0; elseif quality == "IGUI_PaintingQuality_Excellent" then return 0,0,255; elseif quality == "IGUI_PaintingQuality_Impressive" then return 128,0,128; elseif quality == "IGUI_PaintingQuality_Wondrous" then return 255,215,0; elseif quality == "IGUI_PaintingQuality_Masterpiece" then return 255,128,0;
	elseif quality == "IGUI_PaintingQuality_Awful" then return 128,0,0; elseif quality == "IGUI_PaintingQuality_Poor" then return 139,69,19; elseif quality == "IGUI_PaintingQuality_Shoddy" then return 105,105,105; end
	return 255,255,255
end

local function getColorValues( _bool )
	setHighlightedColors()
    if _bool then
        return ISMoveableSpriteProps.ghc:getR()*255, ISMoveableSpriteProps.ghc:getG()*255, ISMoveableSpriteProps.ghc:getB()*255;
    end
    return ISMoveableSpriteProps.bhc:getR()*255, ISMoveableSpriteProps.bhc:getG()*255, ISMoveableSpriteProps.bhc:getB()*255;
end

local function resetInfoPanelFlags()
    InfoPanelFlags.debug = nil;
    InfoPanelFlags.name = nil;
    InfoPanelFlags.weight = nil;
    InfoPanelFlags.hasItems = nil;
    InfoPanelFlags.canRotate = nil;
    InfoPanelFlags.hasSkill = nil;
    InfoPanelFlags.nameSkill = nil;
    InfoPanelFlags.perk = nil
    InfoPanelFlags.levelSkill = nil
    InfoPanelFlags.tool = nil;
    InfoPanelFlags.hasTool = nil;
    InfoPanelFlags.toolString = {}; --contains tools, possibly multiple lines (note to self: only first line tool had prefix)
    InfoPanelFlags.tool2 = nil;
    InfoPanelFlags.hasTool2 = nil;
    InfoPanelFlags.tool2String = {};
    InfoPanelFlags.scrapChance = nil;
    InfoPanelFlags.breakChance = nil;
    InfoPanelFlags.hasCompost = nil;
    InfoPanelFlags.tooHeavy = nil;
    InfoPanelFlags.tooHot = nil;
    InfoPanelFlags.itemsOnSurface = nil;
    InfoPanelFlags.hasWater = nil;
    InfoPanelFlags.notEmpty = nil;
    InfoPanelFlags.doorBarricaded = nil;
    InfoPanelFlags.doorInFrame = nil;
    InfoPanelFlags.floorAtTopOfStairs = nil;
    InfoPanelFlags.windowOpen = nil;
    InfoPanelFlags.windowBarricaded = nil;
    InfoPanelFlags.windowInFrame = nil;
    InfoPanelFlags.needStandingInside = nil;
    InfoPanelFlags.mustPlaceRoomRoof = nil;
    InfoPanelFlags.isOperational = nil; -- for stuff that cant be moved due it being operated (like bbq)
    InfoPanelFlags.removePropane = nil;
end

local function getArtData(object)
	if object:getModData().movableData and object:getModData().movableData['artAuthor'] and object:getModData().movableData['artBeauty'] then return object:getModData().movableData;
	elseif object:getModData().modData and object:getModData().modData.movableData and object:getModData().modData.movableData['artAuthor'] and object:getModData().modData.movableData['artBeauty'] then return object:getModData().modData.movableData; end
	return false
end

local function isArtObject(object)
	if (instanceof(object, "IsoObject") or instanceof(object, "InventoryItem")) and object:hasModData() and ((object:getModData().movableData and
	object:getModData().movableData['artAuthor']) or (object:getModData().modData and object:getModData().modData.movableData and object:getModData().modData.movableData['artAuthor'])) then return true; end
	return false
end

local function getObjCustomName(item)
	local movData = item and (instanceof(item, "IsoObject") or instanceof(item, "InventoryItem")) and item.getModData and item:getModData().movableData
	return movData and movData['customName']
end

local ogPanelDescription = ISMoveableSpriteProps.getInfoPanelDescription
function ISMoveableSpriteProps:getInfoPanelDescription( _square, _object, _player, _mode )
	-- Get Special Object (art or busy invention) conditions, return OG func otherwise / for custom art tooltip, anything without art data returns
	local objCustomName = self.isMoveable and getObjCustomName(_object)
	local isBusyInv = self.isMoveable and LSUtil.isValidObj(_object, "NA") and LSInv.isBusy(_object, nil)
	if (_mode == "scrap" and not self.canScrap) or
	(_mode ~= "scrap" and not self.isMoveable) or
	(not isArtObject(_object) and not isBusyInv and not objCustomName) then return ogPanelDescription(self, _square, _object, _player, _mode); end
	-- Repeat vanilla code
	setHighlightedColors() -- not vanilla, required as some mods override the ISMoveableSpriteProps table, erasing it's contents
    local infoTable = {};
    local bR,bG,bB = ISMoveableSpriteProps.bhc:getR()*255, ISMoveableSpriteProps.bhc:getG()*255, ISMoveableSpriteProps.bhc:getB()*255
    local gR,gG,gB = ISMoveableSpriteProps.ghc:getR()*255, ISMoveableSpriteProps.ghc:getG()*255, ISMoveableSpriteProps.ghc:getB()*255

	if ISMoveableSpriteProps.debug then
		infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "DEBUG", 128, 128, 128 );
		for i=0, self.spriteProps:getPropertyNames():size()-1 do
			local name = self.spriteProps:getPropertyNames():get(i);
			infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, name, 255, 255, 255, tostring(self.spriteProps:get(name)), gR,gG,gB );
		end
		infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "END DEBUG", 128, 128, 128 );
	end

	resetInfoPanelFlags();
	self:getInfoPanelFlagsGeneral( _square, _object, _player, _mode );
	if self.isMoveable and self.isMultiSprite then
		local sgrid = self:getSpriteGridInfo(_square, _mode == "pickup" or _mode == "scrap");
		if sgrid then
			for _,gridMember in ipairs(sgrid) do
				self:getInfoPanelFlagsPerTile( gridMember.square, not gridMember.sprInstance and gridMember.object or nil, _player, _mode );
			end
		end
	else
		self:getInfoPanelFlagsPerTile( _square, _object, _player, _mode );
	end
	-- Art
	local data = getArtData(_object)
	if data then
		if data['artName'] then 
			infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_Name")..":", 255, 255, 255, data['artName'], 255, 255, 255 )
		elseif InfoPanelFlags.name then
			infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_Name")..":", 255, 255, 255, Translator.getMoveableDisplayName(InfoPanelFlags.name), 255, 255, 255 )
		end
		if data['artBeauty'] then
			local pR, pG, pB = 255, 255, 255
			if not data['artQuality'] then data['artQuality'] = "IGUI_PaintingQuality_Normal"; end
			if data['artQuality'] ~= "IGUI_PaintingQuality_Normal" then pR, pG, pB = getbeautyRGB(data['artQuality']); end
			if data['artSize'] and (data['artSize'] == "large") then
				infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingBeauty")..": ", 255, 255, 255, tostring(data['artBeauty']).." - "..getText(data['artQuality']).." (x2)", pR, pG, pB)
			else
				infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingBeauty")..": ", 255, 255, 255, tostring(data['artBeauty']).." - "..getText(data['artQuality']), pR, pG, pB)
			end
		end
		if data['artStyle'] then infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingStyle")..": ", 255, 255, 255, getText("IGUI_PaintingStyle"..data['artStyle']), 255, 255, 255); end
		infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingAuthor")..": ", 255, 255, 255, data['artAuthor'], 255, 255, 0)
	elseif objCustomName then
		infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_Name")..":", 255, 255, 255, objCustomName, 255, 255, 255 )
	end
	-- Repeat end of vanilla code
        if InfoPanelFlags.weight then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("Tooltip_item_Weight")..":", 255, 255, 255, tostring(InfoPanelFlags.weight), 255, 255, 255 ); end
        if InfoPanelFlags.nameSkill then
            local skillText = InfoPanelFlags.nameSkill
            if InfoPanelFlags.levelSkill ~= nil and InfoPanelFlags.levelSkill > 0 then
                skillText = skillText .. " " .. _player:getPerkLevel(InfoPanelFlags.perk) .. "/" .. InfoPanelFlags.levelSkill
            end
            infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_Skill")..":", 255, 255, 255, skillText, getColorValues(InfoPanelFlags.hasSkill) );
        end
        if #InfoPanelFlags.toolString > 0 then
            local first = true;
            for _,s in ipairs(InfoPanelFlags.toolString) do
                if first then
                    infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_Tool")..":", 255, 255, 255, s, getColorValues(InfoPanelFlags.hasTool) );
                else
                    infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "", 255, 255, 255, s, getColorValues(InfoPanelFlags.hasTool) );
                end
                first = false;
            end
        else
            infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_Tool")..":", 255, 255, 255, getText("IGUI_None"), getColorValues(true) );
        end
        if #InfoPanelFlags.tool2String > 0 then
            local first = true;
            for _,s in ipairs(InfoPanelFlags.tool2String) do
                if first then
                    infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_Tool")..":", 255, 255, 255, s, getColorValues(InfoPanelFlags.hasTool2) );
                else
                    infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "", 255, 255, 255, s, getColorValues(InfoPanelFlags.hasTool2) );
                end
                first = false;
            end
        end
        if InfoPanelFlags.scrapChance then
            local chance = ColorInfo.new(0, 0, 0, 1)
            getCore():getBadHighlitedColor():interp(getCore():getGoodHighlitedColor(), InfoPanelFlags.scrapChance/100, chance);
            infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("Tooltip_Chance"), 255, 255, 255, tostring(InfoPanelFlags.scrapChance), chance:getR()*255,chance:getG()*255,chance:getB()*255 );
        end
        if InfoPanelFlags.breakChance then
            local chance = ColorInfo.new(0, 0, 0, 1)
            getCore():getGoodHighlitedColor():interp(getCore():getBadHighlitedColor(), InfoPanelFlags.breakChance/100, chance);
            infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_ChanceToBreak")..":", 255, 255, 255, tostring(InfoPanelFlags.breakChance), chance:getR()*255,chance:getG()*255,chance:getB()*255 );
        end
        if InfoPanelFlags.hasItems then
            infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_ItemsInContainer"), bR,bG,bB );
        end
        if InfoPanelFlags.canRotate~=nil then
            if InfoPanelFlags.canRotate then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_CanRotate"), gR,gG,gB );
            else infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, getText("IGUI_CanNotRotate"), bR,bG,bB ); end
        end
		if isBusyInv then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_Inventions_Busy"), bR,bG,bB ); end
        if InfoPanelFlags.hasCompost then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_ComposterHasCompost"), bR,bG,bB ); end
        if InfoPanelFlags.tooHeavy then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_ToHeavy"), bR,bG,bB ); end
        if InfoPanelFlags.tooHot then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_TooHot"), bR,bG,bB ); end
        if InfoPanelFlags.itemsOnSurface then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_ItemsSurface"), bR,bG,bB ); end
        if InfoPanelFlags.hasWater then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_RainCollectorHasWater"), bR,bG,bB ); end
        if InfoPanelFlags.notEmpty then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_MovableHasMaterial"), bR,bG,bB ); end
        if InfoPanelFlags.doorBarricaded then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_Moveables_DoorBarricaded"), bR,bG,bB ); end
        if InfoPanelFlags.doorInFrame then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_Moveables_DoorInFrame"), bR,bG,bB ); end
        if InfoPanelFlags.floorAtTopOfStairs then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_Moveables_FloorAtTopOfStairs"), bR,bG,bB ); end
        if InfoPanelFlags.windowOpen then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_WindowOpen"), bR,bG,bB ); end
        if InfoPanelFlags.windowBarricaded then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_WindowBarricaded"), bR,bG,bB ); end
        if InfoPanelFlags.windowInFrame then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_Moveables_WindowInFrame"), bR,bG,bB ); end
        if InfoPanelFlags.needStandingInside then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_NeedToBeStandingInside"), bR,bG,bB ); end
        if InfoPanelFlags.mustPlaceRoomRoof then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_MustPlaceRoomRoof"), bR,bG,bB ); end
        if InfoPanelFlags.isOperational then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_IsOperational"), bR,bG,bB ); end
        if InfoPanelFlags.removePropane then infoTable = ISMoveableSpriteProps.addLineToInfoTable( infoTable, "- "..getText("IGUI_RemovePropane"), bR,bG,bB ); end
        --##########################################
        return infoTable;
end
--[[
local ISMoveableSpriteProps_getInfoPanelDescription = ISMoveableSpriteProps.getInfoPanelDescription;
function ISMoveableSpriteProps:getInfoPanelDescription( _square, _object, _player, _mode, ... )
    local infoTable = ISMoveableSpriteProps_getInfoPanelDescription(self, _square, _object, _player, _mode, ...)
    if (instanceof(_object, "IsoObject") or instanceof(_object, "InventoryItem")) and _object:hasModData() and _object:getModData().movableData and _object:getModData().movableData['artAuthor'] then
		if _object:getModData().movableData['artBeauty'] then
			local pR, pG, pB = 255, 255, 255
			if not _object:getModData().movableData['artQuality'] then _object:getModData().movableData['artQuality'] = "IGUI_PaintingQuality_Normal"; end
			if _object:getModData().movableData['artQuality'] ~= "IGUI_PaintingQuality_Normal" then pR, pG, pB = getbeautyRGB(_object:getModData().movableData['artQuality']); end
			if _object:getModData().movableData['artSize'] and (_object:getModData().movableData['artSize'] == "large") then
				infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingBeauty")..": ", 255, 255, 255, tostring(_object:getModData().movableData['artBeauty']).." - "..getText(_object:getModData().movableData['artQuality']).." (x2)", pR, pG, pB)
			else
				infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingBeauty")..": ", 255, 255, 255, tostring(_object:getModData().movableData['artBeauty']).." - "..getText(_object:getModData().movableData['artQuality']), pR, pG, pB)
			end
		end
		if _object:getModData().movableData['artName'] then 
			infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingCustomName")..": ", 255, 255, 255, _object:getModData().movableData['artName'], 255, 255, 255)
		end
		if _object:getModData().movableData['artStyle'] then infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingStyle")..": ", 255, 255, 255, getText("IGUI_PaintingStyle".._object:getModData().movableData['artStyle']), 255, 255, 255); end
		infoTable = ISMoveableSpriteProps.addLineToInfoTable(infoTable, getText("IGUI_PaintingAuthor")..": ", 255, 255, 255, _object:getModData().movableData['artAuthor'], 255, 255, 0)
	end
    return infoTable
end
]]--

--[[ -- removed after 42.13.1
local function hasLSData(item)
	return item:hasModData() and item:getModData().movableData and (item:getModData().movableData['artAuthor'] or item:getModData().movableData['inventionData'])
end

local ogPlaceMov = ISMoveableSpriteProps.placeMoveable
function ISMoveableSpriteProps:placeMoveable( _character, _square, _origSpriteName )
	-- Get Art conditions, return OG func otherwise / single-tile sprites already copy movabledata over in vanilla
	if not self.isMoveable or not instanceof(_character,"IsoGameCharacter") or not instanceof(_square,"IsoGridSquare") or
	not self.isMultiSprite or not self.isForceSingleItem then return ogPlaceMov(self, _character, _square, _origSpriteName); end
	local spriteGrid = self.sprite:getSpriteGrid()
	if not spriteGrid then return false; end
	local sgrid = self:getSpriteGridInfo(_square, false)
	if not sgrid then return false; end
	local item = self:findInInventoryMultiSprite( _character, self.name .. " (1/1)" )
	if not item or not hasLSData(item) then return ogPlaceMov(self, _character, _square, _origSpriteName); end

	-- Run Modified Code
	for i,gridMember in ipairs(sgrid) do
		if not self:canPlaceMoveableInternal( _character, gridMember.square, item ) then
			return false;
		end
	end

	for i,gridMember in ipairs(sgrid) do
		local gridItem = self:instanceItem(gridMember.sprite:getName());
		if gridMember.sprite == spriteGrid:getAnchorSprite() then
			gridItem = item;
		else -- hasLSData(item)
			gridItem:getModData().movableData = copyTable(item:getModData().movableData)
		end
		self:placeMoveableInternal(  gridMember.square, gridItem, gridMember.sprite:getName() )
	end

	_character:getInventory():Remove(item)
	ISMoveableCursor.clearCacheForAllPlayers()

end

local ogPickUpMov = ISMoveableSpriteProps.pickUpMoveable
function ISMoveableSpriteProps:pickUpMoveable( _character, _square, _createItem, _forceAllow )
	-- Get Art conditions, return OG func otherwise / single-tile sprites already copy movabledata over in vanilla
	if not self.isMoveable or not instanceof(_character,"IsoGameCharacter") or not instanceof(_square,"IsoGridSquare") or
	not self.isMultiSprite or not _createItem or not self.isForceSingleItem then return ogPickUpMov(self, _character, _square, _createItem, _forceAllow); end
	local obj, sprInstance = self:findOnSquare( _square, self.spriteName )
	if not obj or not ((_forceAllow or ISMoveableDefinitions.cheat or self:canPickUpMoveable( _character, _square, not sprInstance and obj or nil ))) or
	not obj:hasModData() or not obj:getModData().movableData then return ogPickUpMov(self, _character, _square, _createItem, _forceAllow); end
	local sgrid = self:getSpriteGridInfo(_square, true)
	if not sgrid then return false; end
	local spriteGrid = self.sprite:getSpriteGrid()
	if not spriteGrid then return false; end

	-- Run Modified Code
	local items = {}
	for _,gridMember in ipairs(sgrid) do
		table.insert(items, self:pickUpMoveableInternal( _character, gridMember.square, gridMember.object, gridMember.sprInstance, gridMember.sprite:getName(), false, _forceAllow ));
	end
	local item 	= self:instanceItem(spriteGrid:getAnchorSprite():getName())
	item:getModData().movableData = copyTable(obj:getModData().movableData)

	_character:getInventory():AddItem(item)

	ISMoveableCursor.clearCacheForAllPlayers()
	return items
end
]]--

--[[
function ISMoveableSpriteProps:pickUpMoveableInternal( _character, _square, _object, _sprInstance, _spriteName, _createItem, _rotating )
    --if _object and self:canPickUpMoveable( _character, _square, not _sprInstance and _object or nil ) then
    local objIsIsoWindow = self.type == "Window" and instanceof(_object,"IsoWindow");
    local item 	= self:instanceItem(_spriteName);

    if item or (objIsIsoWindow and _object:isDestroyed()) then      -- destroyed windows return nil for instanceItem()
        local windowGotSmashed = false;
        if not objIsIsoWindow or not _object:isDestroyed() then     -- when its a destroyed window skip this
            if not _rotating and self:doBreakTest( _character ) then
                if self.type ~= "Window" then
                    self:playBreakSound( _character, _object );
                    self:addBreakDebris( _square );
                elseif objIsIsoWindow then
                    if not _object:isDestroyed() then               -- in case of a window, when it breaks and isnt broken yet smash it, leaves no debris.
                        _object:smashWindow();
                        windowGotSmashed = true;
                    end
                end
            elseif item then
                if instanceof(_object, "IsoThumpable") then
                    item:getModData().name = _object:getName() or ""
                    item:getModData().health = _object:getHealth()
                    item:getModData().maxHealth = _object:getMaxHealth()
                    item:getModData().thumpSound = _object:getThumpSound()
                    item:getModData().color = _object:getCustomColor()
                    if _object:hasModData() then
                        item:getModData().modData = copyTable(_object:getModData())
                    end
                else
                    if _object:hasModData() and _object:getModData().movableData then
                        item:getModData().movableData = copyTable(_object:getModData().movableData)
                    end

                    if _object:hasModData() and _object:getModData().itemCondition then
                        item:setConditionMax(_object:getModData().itemCondition.max);
                        item:setCondition(_object:getModData().itemCondition.value);
                    end
                end
                if _createItem then
                    if self.isMultiSprite then
                        _square:AddWorldInventoryItem(item, ZombRandFloat(0.1,0.9), ZombRandFloat(0.1,0.9), 0);
                    else
						if item:hasModData() and item:getModData().movableData and item:getModData().movableData['artName'] then
							item:setName(item:getModData().movableData['artName'])
						end
                        _character:getInventory():AddItem(item);        -- add the item if it aint got broken
                    end
                end
            end
        end

        -- custom/modified light info (custom bulb, use battery etc) for the various lamps can by copied to movable item and retrieved uppon placing;
        if instanceof(_object,"IsoLightSwitch") and _sprInstance==nil then
            _object:setCustomSettingsToItem(item);
            --item:getLightSettings(obj);
        end

        if instanceof(_object, "IsoMannequin") then
            _object:setCustomSettingsToItem(item)
        end

        -- Remove stuff from the world
        if self.type == "WallOverlay" then
            -- A Mirror on the east or south edge of a square.
            if _object:getSprite() and _spriteName and (_object:getSprite():getName() == _spriteName) then
                triggerEvent("OnObjectAboutToBeRemoved", _object) -- Hack for RainCollectorBarrel, Trap, etc
                _square:transmitRemoveItemFromSquare(_object)
            elseif _sprInstance then
                local sprList = _object:getChildSprites();
                local sprIndex = sprList and sprList:indexOf(_sprInstance) or -1
                if sprIndex == -1 then
                else
                    _object:RemoveAttachedAnim(sprIndex)
                    if isClient() then _object:transmitUpdatedSpriteToServer() end
                end
            end
        elseif self.type == "FloorTile" then
            local floor = _square:getFloor();
            local moveableDefinitions = ISMoveableDefinitions:getInstance();
            if moveableDefinitions and moveableDefinitions.floorReplaceSprites then
                local repSprs = moveableDefinitions.floorReplaceSprites;
                local floor = _square:getFloor();
                local spr = getSprite( repSprs[ ZombRand(1,#repSprs) ] );
                if floor and spr then
                    floor:setSprite(spr);
                    if isClient() then floor:transmitUpdatedSpriteToServer(); end --:transmitCompleteItemToServer(); end
                end
            end
        elseif self.isoType == "IsoBrokenGlass" then
            -- add random damage to hands if no gloves
            if not _character:getClothingItem_Hands() and ZombRand(3) == 0 then
                local handPart = _character:getBodyDamage():getBodyPart(BodyPartType.FromIndex(ZombRand(BodyPartType.ToIndex(BodyPartType.Hand_L),BodyPartType.ToIndex(BodyPartType.Hand_R) + 1)))
                handPart:setScratched(true, true);
                -- possible glass in hands
                if ZombRand(5) == 0 then
                    handPart:setHaveGlass(true);
                end
            end
            triggerEvent("OnObjectAboutToBeRemoved", _object)
            _square:transmitRemoveItemFromSquare(_object)
        elseif self.type == "Window" then
            if objIsIsoWindow and not windowGotSmashed then
                if isClient() then _square:transmitRemoveItemFromSquare(_object) end
                _square:RemoveTileObject(_object);
            end
        elseif not _sprInstance then --Objects, Vegitation, WallObjects etc
            if self.isoType == "IsoRadio" or self.isoType == "IsoTelevision" then
                if instanceof(_object,"IsoWaveSignal") then
                    local deviceData = _object:getDeviceData();
                    if deviceData then
                        item:setDeviceData(deviceData);
                    else
                        print("Warning: device data missing?>?")
                    end
                end
            end
            if self.spriteProps and not self.spriteProps:has(IsoFlagType.waterPiped) then
                --print("water check");
                if _object:hasModData() then
                    --print("water check mod data");
                    if _object:getModData().waterAmount then
                        item:getModData().waterAmount = _object:getModData().waterAmount;
                        item:getModData().taintedWater = _object:isTaintedWater();
                    end
                else
                    --print("water check no mod");
                    local waterAmount = tonumber(_object:getFluidAmount());
                    if waterAmount then
                        item:getModData().waterAmount = waterAmount;
                        item:getModData().taintedWater = _object:isTaintedWater();
                end
                end
                --print("ITEM WATER AMOUNT = "..tostring(item:getModData().waterAmount));
            end
            triggerEvent("OnObjectAboutToBeRemoved", _object) -- Hack for RainCollectorBarrel, Trap, etc
            _square:transmitRemoveItemFromSquare(_object)
        end
        _square:RecalcProperties();
        _square:RecalcAllWithNeighbours(true);

        --ISMoveableCursor.clearCacheForAllPlayers();

        triggerEvent("OnContainerUpdate")

        IsoGenerator.updateGenerator(_square)
        return item;
    end
    --end
end
]]--

--[[
local ISMoveableSpriteProps_pickUpMoveableInternal = ISMoveableSpriteProps.pickUpMoveableInternal;
function ISMoveableSpriteProps:pickUpMoveableInternal( _character, _square, _object, ... )
    local item = ISMoveableSpriteProps_pickUpMoveableInternal(self, _character, _square, _object, ...)
	if instanceof(item, "InventoryItem") and instanceof(_object, "IsoObject") and _object:hasModData() and _object:getModData().movableData then
		item:getModData().movableData = copyTable(_object:getModData().movableData)
	end
    return item
end
--]]

--[[
local ISMoveableSpriteProps_placeMoveableInternal = ISMoveableSpriteProps.placeMoveableInternal
function ISMoveableSpriteProps:placeMoveableInternal( _square, _item, _spriteName )
	if _item and instanceof(_item, "InventoryItem") and _item:hasModData() and _item:getModData().movableData and _item:getModData().movableData['artName'] then
		_item:getModData().name = _item:getModData().movableData['artName']
	end
    ISMoveableSpriteProps_placeMoveableInternal( _square, _item, _spriteName )
end
]]--

--[[
local ISMoveableSpriteProps_placeMoveableInternal = ISMoveableSpriteProps.placeMoveableInternal;
function ISMoveableSpriteProps:placeMoveableInternal( _square, _item, _spriteName )
	ISMoveableSpriteProps_placeMoveableInternal( _square, _item, _spriteName )
	if _spriteName and (luautils.stringStarts(_spriteName, "LS_Painting_")) then
        local objects = _square:getObjects()
		for i=1,objects:size() do
			local thisObject = square:getObjects():get(i-1)
			if thisObject and instanceof(thisObject, "IsoObject") and (thisObject:hasModData()) and thisObject:getModData().movableData and thisObject:getModData().movableData['artFrame'] then
				local properties = thisObject:getSprite():getProperties()
				if properties:has("Facing") then
					local facing = properties:get("Facing")
					if thisObject:getModData().movableData['artFrame'].size ~= "large" then
						thisObject:setOverlaySprite(thisObject:getModData().movableData.artFrame['texture'..facing], isClient())
						if isClient() then
							thisObject:transmitUpdatedSpriteToServer()
						end
					else
						--to get large by the correct frame we can use properties:get("SpriteGridPos")
					end
				end	
			end
		end	
	end
end
]]--

local function findPaintingFrame(thisObject)

	if thisObject and instanceof(thisObject, "IsoObject") and thisObject:hasModData() and thisObject:getModData().movableData and thisObject:getModData().movableData['artFrame'] then
		local properties = thisObject:getSprite():getProperties()
		if properties:has("Facing") then
			local facing = properties:get("Facing")
			if thisObject:getModData().movableData['artFrame'].size ~= "large" then
				local frameOverlaySprite = thisObject:getModData().movableData.artFrame['texture'..facing]
				if isClient() then
					sendClientCommand("LS", "ModifyOverlaySprite", {{thisObject:getX(),thisObject:getY(),thisObject:getZ(),thisObject:getSprite():getName()}, frameOverlaySprite})
				else
					thisObject:setOverlaySprite(frameOverlaySprite, isClient())
				end
			elseif properties:has("SpriteGridPos") then
				--to get large by the correct frame we can use properties:get("SpriteGridPos")
				local gridPos = properties:get("SpriteGridPos")
				local frameOverlaySprite
				if ((facing == "E") and (gridPos == "0,0")) or ((facing == "S") and (gridPos == "1,0")) then
					frameOverlaySprite = thisObject:getModData().movableData.artFrame['texture'..facing..'2']
				else
					frameOverlaySprite = thisObject:getModData().movableData.artFrame['texture'..facing]
				end
				if isClient() then
					sendClientCommand("LS", "ModifyOverlaySprite", {{thisObject:getX(),thisObject:getY(),thisObject:getZ(),thisObject:getSprite():getName()}, frameOverlaySprite})
				else
					thisObject:setOverlaySprite(frameOverlaySprite, isClient())
				end
			end
		end	
	end
end

Events.OnObjectAdded.Add(findPaintingFrame)



