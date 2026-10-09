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

local function hasLSData(item)
	return item:hasModData() and item:getModData().movableData and (item:getModData().movableData['artAuthor'] or item:getModData().movableData['inventionData'])
end

local ogPlaceMov = ISMoveableSpriteProps.placeMoveable
function ISMoveableSpriteProps:placeMoveable( _character, _square, _origSpriteName, _forceAllow )
	-- Get Art conditions, return OG func otherwise / single-tile sprites already copy movabledata over in vanilla
	if not self.isMoveable or not instanceof(_character,"IsoGameCharacter") or not instanceof(_square,"IsoGridSquare") or
	not self.isMultiSprite or not self.isForceSingleItem then return ogPlaceMov(self, _character, _square, _origSpriteName, _forceAllow); end
	local spriteGrid = self.sprite:getSpriteGrid()
	if not spriteGrid then return false; end
	local sgrid = self:getSpriteGridInfo(_square, false)
	if not sgrid then return false; end
	local item = self:findInInventoryMultiSprite( _character, self.name .. " (1/1)" )
	if not item or not hasLSData(item) then return ogPlaceMov(self, _character, _square, _origSpriteName, _forceAllow); end

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
	sendRemoveItemFromContainer(_character:getInventory(), item)
	ISMoveableCursor.clearCacheForAllPlayers()

end

local ogPickUpMov = ISMoveableSpriteProps.pickUpMoveable
function ISMoveableSpriteProps:pickUpMoveable( _character, _square, _createItem, _forceAllow )
	-- Get Art conditions, return OG func otherwise / single-tile sprites already copy movabledata over in vanilla
	if not self.isMoveable or not instanceof(_character,"IsoGameCharacter") or not instanceof(_square,"IsoGridSquare") or
	not self.isMultiSprite or not _createItem or not self.isForceSingleItem then return ogPickUpMov(self, _character, _square, _createItem, _forceAllow); end
	local obj, sprInstance = self:findOnSquare( _square, self.spriteName )
	if not obj or not ((_forceAllow or _character:isMovablesCheat() or ISMoveableDefinitions.cheat or self:canPickUpMoveable( _character, _square, not sprInstance and obj or nil ))) or
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
	if instanceof(obj, "IsoThumpable") then
		self:saveThumpableParameters(item:getModData(), obj);
	end
	_character:getInventory():AddItem(item)
	sendAddItemToContainer(_character:getInventory(), item)
	ISMoveableCursor.clearCacheForAllPlayers()
	return items
end

local ogCanPickUpMovInternal = ISMoveableSpriteProps.canPickUpMoveableInternal
function ISMoveableSpriteProps:canPickUpMoveableInternal( _character, _square, _object, _isMulti )
	-- If running invention return false, otherwise return og func
	if LSUtil.isValidObj(_object, self.spriteName) and LSInv.isBusy(_object, nil) then return false; end 
	return ogCanPickUpMovInternal(self, _character, _square, _object, _isMulti)
end
