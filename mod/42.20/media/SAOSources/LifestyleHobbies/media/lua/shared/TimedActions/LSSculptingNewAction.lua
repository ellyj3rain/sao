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

require "TimedActions/ISBaseTimedAction"

LSSculptingNewAction = ISBaseTimedAction:derive("LSSculptingNewAction");

function LSSculptingNewAction:isValid()
	if self.res and self.res[1] then
		local invItem = self.character:getInventory():getItemCount(self.res[1], true)
		if invItem < self.res[2] then return false; end
	end
	return true
end

function LSSculptingNewAction:waitToStart()
	self.action:setUseProgressBar(false)
	self.character:faceThisObject(self.station);
	return self.character:shouldBeTurning();
end

function LSSculptingNewAction:update()
	if self.character:isSitOnGround() then self:forceStop(); end

end

function LSSculptingNewAction:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "High")
	self.character:getEmitter():playSound("PutItemInBag")
end

function LSSculptingNewAction:stop()
	self.character:SetVariable("LootPosition", "Mid")
    ISBaseTimedAction.stop(self);		
end

local function isIceSculpture(station)
	return station:getModData().style and (station:getModData().style == "Ice")
end

local function consumeItems(thisPlayer, material, itemList)
	local consumed = 0
	for x=0,itemList:size() - 1 do
		local item = itemList:get(x)
		local itemCont = item:getContainer()
		if not item:IsClothing() or not thisPlayer:isEquippedClothing(item) then
			itemCont:DoRemoveItem(item)
			itemCont:setDrawDirty(true)
			sendRemoveItemFromContainer(itemCont, item)
			sendItemStats(item)
			consumed = consumed+1
			if consumed >= material[2] then break; end
		end
	end
	if material[3] then
		for n=1, material[2] do
			local item = instanceItem(material[3])
			thisPlayer:getInventory():AddItem(item)
			thisPlayer:getInventory():setDrawDirty(true)
			sendAddItemToContainer(thisPlayer:getInventory(), item)
			sendItemStats(item)
		end
	end
end

function LSSculptingNewAction:perform()
	--[[
	if self.saveSculpture then
		if isIceSculpture(self.station) then self.station:getModData().sculpture["meltTime"] = 32000; end
		sendClientCommand(self.character, "LS", "CreateArtworkItem", {self.station:getModData().author, self.station:getModData().sculpture})
	end
	self.station:getModData().stage = 0
	self.station:getModData().sculpture = false
	self.station:getModData().author = false
	self.station:getModData().style = self.style
	sendClientCommand("LS", "ModifySprite", {{self.station:getX(),self.station:getY(),self.station:getZ(),self.station:getSprite():getName()}, self.newStation, self.overlay})
	sendClientCommand("LS", "ModifyObjData", {{self.station:getX(),self.station:getY(),self.station:getZ(),self.station:getSprite():getName()}, false, self.station:getModData()})
	]]--
	self.character:SetVariable("LootPosition", "Mid")
	ISBaseTimedAction.perform(self);
end


function LSSculptingNewAction:complete()
	if self.saveSculpture then
		if isIceSculpture(self.station) then self.station:getModData().sculpture["meltTime"] = 32000; end
		LSUtil.createArtworkItem(self.character, {self.station:getModData().author, self.station:getModData().sculpture})
	elseif self.res and self.res[1] then
		consumeItems(self.character, self.res, self.character:getInventory():getItemsFromType(self.res[1], true))
	end
	self.station:getModData().stage = 0
	self.station:getModData().sculpture = false
	self.station:getModData().author = false
	self.station:getModData().style = self.style

	self.station:setOverlaySprite(self.overlay, true)
	self.station:setSprite(self.newStation)
	self.station:transmitUpdatedSpriteToClients()
	self.station:transmitModData()
	return true
end

function LSSculptingNewAction:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 60
end

function LSSculptingNewAction:new(character, station, newStation, overlay, style, res, saveSculpture)
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.station = station
	o.newStation = newStation
	o.saveSculpture = saveSculpture
	o.overlay = overlay
	o.style = style
	o.res = res
	o.newItem = false
	o.ignoreDynamicTime = true;
    o.stopOnWalk        = true;
    o.stopOnRun         = true;
	o.maxTime = o:getDuration()
	return o;
end
