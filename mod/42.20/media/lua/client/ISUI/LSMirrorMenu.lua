-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
require "ISUI/ISPanelJoypad"

LS_AMcache['tattoo'] = LS_AMcache['tattoo'] or (not LS_AMcache['tattoo_cached'] and LS_PatchUtils.hasCompatMod('tattoo'))

--require "Helper/TransferHelper"
LSMirrorMenu = ISPanelJoypad:derive("LSMirrorMenu")

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local header_height = FONT_HGT_SMALL + 14
local MMbottomMenuButtonList = {}
local bottomMenuSqrList = {}
local bottomMenuModelList = {}
local MMmenuList = {}
local MMcircleList = {}
local MMcircleSubList = {}

local function MirrorItemContainer(player, itemA)

	local Cont = false

	if instanceof(itemA, "InventoryItem") then
		if luautils.haveToBeTransfered(player, itemA) then
			Cont = itemA:getContainer()
		end
	elseif instanceof(itemA, "ArrayList") then
		local items = itemA
		for i=1,items:size() do
			local item = items:get(i-1)
			if luautils.haveToBeTransfered(player, item) then
				Cont = item:getContainer()
				break
			end
		end
	end

	return Cont
end

local function MMgetMakeupBodyLocationItem(character, makeupCat)
	local bodyLocationItem
	for i,v in ipairs(MakeUpDefinitions.makeup) do
		if v.category == makeupCat then
			local makeup = instanceItem(v.item)
			if makeup then bodyLocationItem = character:getWornItem(makeup:getBodyLocation()); end
			--if bodyLocationItem then print("MMgetMakeupBottomOptions: found an item for bodyLocationItem, name is: " .. bodyLocationItem:getName()); break; end
			if bodyLocationItem then break; end
		end
	end
	return bodyLocationItem
end

local function MMgetConsumable(character, oldItem)

    local inventory = character:getInventory();
	local it = inventory:getItems();
	local newItem

	for j = 0, it:size()-1 do
		local item = it:get(j);
		if item:getType() == oldItem:getType() then
			newItem = item
			break
		end
	end

	return newItem
end

local function MMdoContainerTransfer(character, Itemcontainer, item)

	Itemcontainer:setHasBeenLooted(true);
	Itemcontainer:removeItemOnServer(item)
	Itemcontainer:DoRemoveItem(item)
	character:getInventory():AddItem(item)
	--item:Use();
	--local useDelta = item:getUseDelta()


	--if item and character:getInventory():contains(item) then


	--------------ITEMTRANSFER -- skipping this for now. Seems item use delta value won't be consistent in mp if transfer is done too soon
		--if Itemcontainer:isItemAllowed(item) then
			--if Itemcontainer:getType() == "floor" then
			--	TransferHelper.dropItem(item, character)
			--else
			--	TransferHelper.onMoveItemsTo(item, Itemcontainer, character, true)
			--end
		--end


		--local newItem = MMgetConsumable(character, item)
		--if newItem then
			--Itemcontainer:addItemOnServer(item);
			--character:getInventory():DoRemoveItem(item);
			--Itemcontainer:setDrawDirty(true);
			--Itemcontainer:AddItem(item)
			--sendClientCommand(character, "LS", "MMaskforItemDelta", {item, useDelta, Itemcontainer}) -- can't send item value
		--end

		--character:getInventory():DoRemoveItem(item)
		--ISTimedActionQueue.add(ISInventoryTransferAction:new(character, item, character:getInventory(), Itemcontainer))
	--end
end

local function MMhasTattooChange(self)
	local categories = {{"Face_Tattoo","resetMakeupTattooFace"},{"UpperBody_Tattoo","resetMakeupTattooUB"},{"LowerBody_Tattoo","resetMakeupTattooLB"},{"Back_Tattoo","resetMakeupTattooBack"},{"LeftArm_Tattoo","resetMakeupTattooLA"},{"RightArm_Tattoo","resetMakeupTattooRA"},{"LeftLeg_Tattoo","resetMakeupTattooLL"},{"RightLeg_Tattoo","resetMakeupTattooRL"}}
	for _, category in ipairs(categories) do
		if self[category[2]] ~= 0 then
			local current = MMgetMakeupBodyLocationItem(self.character, category[1])
			if current and current ~= self[category[2]] then return true; end
		end
	end
	return false
end

function LSMirrorMenu:onConfirmChanges(button)
	local useTattoo = MMhasTattooChange(self)

	if self.hairDyeItem then
		self.character:getHumanVisual():setHairColor(ImmutableColor.new(self.hairDyeItem:getFluidContainer():getColor():getR(), self.hairDyeItem:getFluidContainer():getColor():getG(), self.hairDyeItem:getFluidContainer():getColor():getB(), 1));
		self.resetHairColor = false
		if not isClient() then
		local Itemcontainer = MirrorItemContainer(self.character, self.hairDyeItem)
		if Itemcontainer then
			MMdoContainerTransfer(self.character, Itemcontainer , self.hairDyeItem)
		end
		 self.hairDyeItem:Use()
		end
	end
	if self.beardDyeItem then
		self.character:getHumanVisual():setBeardColor(ImmutableColor.new(self.beardDyeItem:getFluidContainer():getColor():getR(), self.beardDyeItem:getFluidContainer():getColor():getG(), self.beardDyeItem:getFluidContainer():getColor():getB(), 1));
		self.resetBeardColor = false
		if not isClient() then
		local Itemcontainer = MirrorItemContainer(self.character, self.beardDyeItem)
		if Itemcontainer then
			MMdoContainerTransfer(self.character, Itemcontainer , self.beardDyeItem)
			--self.beardDyeItem:Use()
			--Itemcontainer:requestSync()
		end
		self.beardDyeItem:Use()
		end
	end
	self.resetHairChange = false
	self.resetBeardChange = false

	if useTattoo and not isClient() and self.itemsList.MakeupTattooNeedle then
		local Itemcontainer = MirrorItemContainer(self.character, self.itemsList.MakeupTattooNeedle)
		if Itemcontainer then
			MMdoContainerTransfer(self.character, Itemcontainer , self.itemsList.MakeupTattooNeedle)
		end
		self.itemsList.MakeupTattooNeedle:Use()
	end

	if self.acidBrush and not isClient() then
		local Itemcontainer = MirrorItemContainer(self.character, self.itemsList.MakeupTattooBrush)
		if Itemcontainer then
			MMdoContainerTransfer(self.character, Itemcontainer , self.itemsList.MakeupTattooBrush)
		end
		self.itemsList.MakeupTattooBrush:Use()
	end

	local makeupData
	if isClient() then
		makeupData = {"FullFace", self.resetMakeupFull, "Eyes", self.resetMakeupEye, "EyesShadow", self.resetMakeupEyeShadow, "Lips", self.resetMakeupLipstick, "Face_Tattoo", self.resetMakeupTattooFace, "UpperBody_Tattoo", self.resetMakeupTattooUB,
		"LowerBody_Tattoo", self.resetMakeupTattooLB, "Back_Tattoo", self.resetMakeupTattooBack, "LeftArm_Tattoo", self.resetMakeupTattooLA, "RightArm_Tattoo", self.resetMakeupTattooRA, "LeftLeg_Tattoo", self.resetMakeupTattooLL,
		"RightLeg_Tattoo", self.resetMakeupTattooRL}
		sendClientCommand(self.character, "LS", "SetMirrorMakeup", {{self.hairDyeItem, self.beardDyeItem, useTattoo and self.itemsList.MakeupTattooNeedle, self.acidBrush and self.itemsList.MakeupTattooBrush}, makeupData})
	end

	local makeupCategories = {FullFace=true,Eyes=true,EyesShadow=true,Lips=true,Face_Tattoo=true,UpperBody_Tattoo=true,LowerBody_Tattoo=true,Back_Tattoo=true,LeftArm_Tattoo=true,RightArm_Tattoo=true,LeftLeg_Tattoo=true,
	RightLeg_Tattoo=true}
	makeupData = {"FullFace", "resetMakeupFull", "Eyes", "resetMakeupEye", "EyesShadow", "resetMakeupEyeShadow", "Lips", "resetMakeupLipstick", "Face_Tattoo", "resetMakeupTattooFace", "UpperBody_Tattoo", "resetMakeupTattooUB",
		"LowerBody_Tattoo", "resetMakeupTattooLB", "Back_Tattoo", "resetMakeupTattooBack", "LeftArm_Tattoo", "resetMakeupTattooLA", "RightArm_Tattoo", "resetMakeupTattooRA", "LeftLeg_Tattoo", "resetMakeupTattooLL",
		"RightLeg_Tattoo", "resetMakeupTattooRL"}

	local bodyLocationItem
	local playerInv = self.character:getInventory()
	for n=1,#makeupData do
		local data = makeupData[n]
		if data and makeupCategories[data] then
			bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, data)
		elseif bodyLocationItem then
			if self[data] ~= 0 then
				if not isClient() then
					playerInv:AddItem(bodyLocationItem)
					if self[data] and playerInv:contains(self[data]) then 
						playerInv:Remove(self[data])
					end
					--if bodyLocationItem.Use then
					--	bodyLocationItem:Use()
					--end
				end
				self[data] = 0
			end
			bodyLocationItem = false
		end
	end

	self.character:resetModel();
	sendVisual(self.character);
	triggerEvent("OnClothingUpdated", self.character)

	self:destroy()
end

function LSMirrorMenu:onResetChange(button)
	local bodyLocationItem
    if button.internal == "resetHairColor" then
        if self.resetHairColor then self.character:getHumanVisual():setHairColor(self.resetHairColor); end
		self.resetHairColor = false
		self.hairDyeItem = false
	elseif button.internal == "resetBeardColor" then
        if self.resetBeardColor then self.character:getHumanVisual():setBeardColor(self.resetBeardColor); end
		self.resetBeardColor = false
		self.beardDyeItem = false
	elseif button.internal == "resetBeardChange" then
        if self.resetBeardChange then self.character:getHumanVisual():setBeardModel(self.resetBeardChange); end
		self.resetBeardChange = false
	elseif button.internal == "resetHairChange" then
        if self.resetHairChange then self.character:getHumanVisual():setHairModel(self.resetHairChange); end
		self.resetHairChange = false
	elseif button.internal == "resetMakeupFull" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "FullFace")
		if (self.resetMakeupFull ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupFull and (self.resetMakeupFull ~= 0) then self.character:setWornItem(self.resetMakeupFull:getBodyLocation(), self.resetMakeupFull); end;
		self.resetMakeupFull = 0
	elseif button.internal == "resetMakeupEye" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Eyes")
		if (self.resetMakeupEye ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupEye and (self.resetMakeupEye ~= 0) then self.character:setWornItem(self.resetMakeupEye:getBodyLocation(), self.resetMakeupEye); end;
		self.resetMakeupEye = 0
	elseif button.internal == "resetMakeupEyeShadow" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "EyesShadow")
		if (self.resetMakeupEyeShadow ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupEyeShadow and (self.resetMakeupEyeShadow ~= 0) then self.character:setWornItem(self.resetMakeupEyeShadow:getBodyLocation(), self.resetMakeupEyeShadow); end;
		self.resetMakeupEyeShadow = 0
	elseif button.internal == "resetMakeupLipstick" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Lips")
		if (self.resetMakeupLipstick ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupLipstick and (self.resetMakeupLipstick ~= 0) then self.character:setWornItem(self.resetMakeupLipstick:getBodyLocation(), self.resetMakeupLipstick); end;
		self.resetMakeupLipstick = 0
	elseif button.internal == "resetMakeupTattooFace" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Face_Tattoo")
		if (self.resetMakeupTattooFace ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooFace and (self.resetMakeupTattooFace ~= 0) then self.character:setWornItem(self.resetMakeupTattooFace:getBodyLocation(), self.resetMakeupTattooFace); end;
		self.resetMakeupTattooFace = 0
	elseif button.internal == "resetMakeupTattooUB" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "UpperBody_Tattoo")
		if (self.resetMakeupTattooUB ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooUB and (self.resetMakeupTattooUB ~= 0) then self.character:setWornItem(self.resetMakeupTattooUB:getBodyLocation(), self.resetMakeupTattooUB); end;
		self.resetMakeupTattooUB = 0
	elseif button.internal == "resetMakeupTattooLB" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LowerBody_Tattoo")
		if (self.resetMakeupTattooLB ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLB and (self.resetMakeupTattooLB ~= 0) then self.character:setWornItem(self.resetMakeupTattooLB:getBodyLocation(), self.resetMakeupTattooLB); end;
		self.resetMakeupTattooLB = 0
	elseif button.internal == "resetMakeupTattooBack" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Back_Tattoo")
		if (self.resetMakeupTattooBack ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooBack and (self.resetMakeupTattooBack ~= 0) then self.character:setWornItem(self.resetMakeupTattooBack:getBodyLocation(), self.resetMakeupTattooBack); end;
		self.resetMakeupTattooBack = 0
	elseif button.internal == "resetMakeupTattooLA" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftArm_Tattoo")
		if (self.resetMakeupTattooLA ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLA and (self.resetMakeupTattooLA ~= 0) then self.character:setWornItem(self.resetMakeupTattooLA:getBodyLocation(), self.resetMakeupTattooLA); end;
		self.resetMakeupTattooLA = 0
	elseif button.internal == "resetMakeupTattooRA" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightArm_Tattoo")
		if (self.resetMakeupTattooRA ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooRA and (self.resetMakeupTattooRA ~= 0) then self.character:setWornItem(self.resetMakeupTattooRA:getBodyLocation(), self.resetMakeupTattooRA); end;
		self.resetMakeupTattooRA = 0
	elseif button.internal == "resetMakeupTattooLL" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftLeg_Tattoo")
		if (self.resetMakeupTattooLL ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLL and (self.resetMakeupTattooLL ~= 0) then self.character:setWornItem(self.resetMakeupTattooLL:getBodyLocation(), self.resetMakeupTattooLL); end;
		self.resetMakeupTattooLL = 0
	elseif button.internal == "resetMakeupTattooRL" then
		bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightLeg_Tattoo")
		if (self.resetMakeupTattooRL ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooRL and (self.resetMakeupTattooRL ~= 0) then self.character:setWornItem(self.resetMakeupTattooRL:getBodyLocation(), self.resetMakeupTattooRL); end;
		self.resetMakeupTattooRL = 0
	end

	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.character:resetModel();
	sendVisual(self.character);
	self.playermodel:setCharacter(self.character)
end

function LSMirrorMenu:onResetChangeAll(button)

	if self.resetHairColor then self.character:getHumanVisual():setHairColor(self.resetHairColor); self.resetHairColor = false; self.hairDyeItem = false; end
	if self.resetBeardColor then self.character:getHumanVisual():setBeardColor(self.resetBeardColor); self.resetBeardColor = false; self.beardDyeItem = false; end
	if self.resetHairChange then self.character:getHumanVisual():setHairModel(self.resetHairChange); end
	if self.resetBeardChange then self.character:getHumanVisual():setBeardModel(self.resetBeardChange); end

	local bodyLocationItem
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "FullFace")
	if (self.resetMakeupFull ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupFull and (self.resetMakeupFull ~= 0) then self.character:setWornItem(self.resetMakeupFull:getBodyLocation(), self.resetMakeupFull); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Eyes")
	if (self.resetMakeupEye ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupEye and (self.resetMakeupEye ~= 0) then self.character:setWornItem(self.resetMakeupEye:getBodyLocation(), self.resetMakeupEye); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "EyesShadow")
	if (self.resetMakeupEyeShadow ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupEyeShadow and (self.resetMakeupEyeShadow ~= 0) then self.character:setWornItem(self.resetMakeupEyeShadow:getBodyLocation(), self.resetMakeupEyeShadow); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Lips")
	if (self.resetMakeupLipstick ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupLipstick and (self.resetMakeupLipstick ~= 0) then self.character:setWornItem(self.resetMakeupLipstick:getBodyLocation(), self.resetMakeupLipstick); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Face_Tattoo")
	if (self.resetMakeupTattooFace ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooFace and (self.resetMakeupTattooFace ~= 0) then self.character:setWornItem(self.resetMakeupTattooFace:getBodyLocation(), self.resetMakeupTattooFace); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "UpperBody_Tattoo")
	if (self.resetMakeupTattooUB ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooUB and (self.resetMakeupTattooUB ~= 0) then self.character:setWornItem(self.resetMakeupTattooUB:getBodyLocation(), self.resetMakeupTattooUB); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LowerBody_Tattoo")
	if (self.resetMakeupTattooLB ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLB and (self.resetMakeupTattooLB ~= 0) then self.character:setWornItem(self.resetMakeupTattooLB:getBodyLocation(), self.resetMakeupTattooLB); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Back_Tattoo")
	if (self.resetMakeupTattooBack ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooBack and (self.resetMakeupTattooBack ~= 0) then self.character:setWornItem(self.resetMakeupTattooBack:getBodyLocation(), self.resetMakeupTattooBack); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftArm_Tattoo")
	if (self.resetMakeupTattooLA ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLA and (self.resetMakeupTattooLA ~= 0) then self.character:setWornItem(self.resetMakeupTattooLA:getBodyLocation(), self.resetMakeupTattooLA); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightArm_Tattoo")
	if (self.resetMakeupTattooRA ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooRA and (self.resetMakeupTattooRA ~= 0) then self.character:setWornItem(self.resetMakeupTattooRA:getBodyLocation(), self.resetMakeupTattooRA); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftLeg_Tattoo")
	if (self.resetMakeupTattooLL ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLL and (self.resetMakeupTattooLL ~= 0) then self.character:setWornItem(self.resetMakeupTattooLL:getBodyLocation(), self.resetMakeupTattooLL); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightLeg_Tattoo")
	if (self.resetMakeupTattooRL ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooRL and (self.resetMakeupTattooRL ~= 0) then self.character:setWornItem(self.resetMakeupTattooRL:getBodyLocation(), self.resetMakeupTattooRL); end;

	self.resetMakeupFull = 0; self.resetMakeupEye = 0; self.resetMakeupEyeShadow = 0; self.resetMakeupLipstick = 0
	self.resetMakeupTattooFace = 0; self.resetMakeupTattooUB = 0; self.resetMakeupTattooLB = 0; self.resetMakeupTattooBack = 0
	self.resetMakeupTattooLA = 0; self.resetMakeupTattooRA = 0; self.resetMakeupTattooLL = 0; self.resetMakeupTattooRL = 0


	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	button:setEnable(false)
	self.character:resetModel();
	sendVisual(self.character);
	self.playermodel:setCharacter(self.character)
end

function LSMirrorMenu:onRemoveMakeup(button)

	local bodyLocationItem
	for i,v in ipairs(MakeUpDefinitions.makeup) do
		if v.category == button.internal then
			local makeup = instanceItem(v.item)
			bodyLocationItem = self.character:getWornItem(makeup:getBodyLocation())
			if bodyLocationItem then break; end
		end
	end

	if not bodyLocationItem then return; end

	if button.internal == "FullFace" then self.character:removeWornItem(bodyLocationItem); self.resetMakeupFull = 0;
	elseif button.internal == "Eyes" then self.character:removeWornItem(bodyLocationItem); self.resetMakeupEye = 0;
	elseif button.internal == "EyesShadow" then self.character:removeWornItem(bodyLocationItem); self.resetMakeupEyeShadow = 0;
	elseif button.internal == "Lips" then self.character:removeWornItem(bodyLocationItem); self.resetMakeupLipstick = 0;
	
	elseif button.internal == "Face_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooFace = 0; elseif button.internal == "UpperBody_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooUB = 0;
	elseif button.internal == "LowerBody_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooLB = 0; elseif button.internal == "Back_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooBack = 0;
	elseif button.internal == "LeftArm_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooLA = 0; elseif button.internal == "RightArm_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooRA = 0;
	elseif button.internal == "LeftLeg_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooLL = 0; elseif button.internal == "RightLeg_Tattoo" then self.acidBrush=true; self.character:removeWornItem(bodyLocationItem); self.resetMakeupTattooRL = 0;
	end

	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.character:resetModel();
	sendVisual(self.character);
	self.playermodel:setCharacter(self.character)
end


local function LMMHighlightBOSquare(idxStatic, menuSkin)
	for idx=1,8 do
		if (idx ~= idxStatic) and (bottomMenuSqrList[idx]:getTexture() == getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQRON.png")) then
			bottomMenuSqrList[idx].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")
		elseif (idx == idxStatic) and (bottomMenuSqrList[idx]:getTexture() == getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")) then
			bottomMenuSqrList[idx].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQRON.png")
		end
	end
end

function LSMirrorMenu:onClickMakeupPreview(button)
	local makeup = button.onClickArgs[1]
	local makeupCat = button.onClickArgs[2]
	local idxStatic = button.onClickArgs[3]
	local bodyLocationItem
	
	if self.resetMakeupFull and (self.resetMakeupFull == 0) and (makeupCat == "FullFace") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "FullFace"); self.resetMakeupFull = bodyLocationItem; end
	if self.resetMakeupEye and (self.resetMakeupEye == 0) and (makeupCat == "Eyes") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Eyes"); self.resetMakeupEye = bodyLocationItem; end
	if self.resetMakeupEyeShadow and (self.resetMakeupEyeShadow == 0) and (makeupCat == "EyesShadow") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "EyesShadow"); self.resetMakeupEyeShadow = bodyLocationItem; end
	if self.resetMakeupLipstick and (self.resetMakeupLipstick == 0) and (makeupCat == "Lips") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Lips"); self.resetMakeupLipstick = bodyLocationItem; end

	if self.resetMakeupTattooFace and (self.resetMakeupTattooFace == 0) and (makeupCat == "Face_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Face_Tattoo"); self.resetMakeupTattooFace = bodyLocationItem; end
	if self.resetMakeupTattooUB and (self.resetMakeupTattooUB == 0) and (makeupCat == "UpperBody_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "UpperBody_Tattoo"); self.resetMakeupTattooUB = bodyLocationItem; end
	if self.resetMakeupTattooLB and (self.resetMakeupTattooLB == 0) and (makeupCat == "LowerBody_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LowerBody_Tattoo"); self.resetMakeupTattooLB = bodyLocationItem; end
	if self.resetMakeupTattooBack and (self.resetMakeupTattooBack == 0) and (makeupCat == "Back_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Back_Tattoo"); self.resetMakeupTattooBack = bodyLocationItem; end

	if self.resetMakeupTattooLA and (self.resetMakeupTattooLA == 0) and (makeupCat == "LeftArm_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftArm_Tattoo"); self.resetMakeupTattooLA = bodyLocationItem; end
	if self.resetMakeupTattooRA and (self.resetMakeupTattooRA == 0) and (makeupCat == "RightArm_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightArm_Tattoo"); self.resetMakeupTattooRA = bodyLocationItem; end
	if self.resetMakeupTattooLL and (self.resetMakeupTattooLL == 0) and (makeupCat == "LeftLeg_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftLeg_Tattoo"); self.resetMakeupTattooLL = bodyLocationItem; end
	if self.resetMakeupTattooRL and (self.resetMakeupTattooRL == 0) and (makeupCat == "RightLeg_Tattoo") then bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightLeg_Tattoo"); self.resetMakeupTattooRL = bodyLocationItem; end

	LMMHighlightBOSquare(idxStatic, self.menuSkin)

	local modelDefs
	if (makeupCat == "FullFace") then self.resetSpecificButton.internal = "resetMakeupFull";
	elseif (makeupCat == "Eyes") then self.resetSpecificButton.internal = "resetMakeupEye";
	elseif (makeupCat == "EyesShadow") then self.resetSpecificButton.internal = "resetMakeupEyeShadow";
	elseif (makeupCat == "Lips") then self.resetSpecificButton.internal = "resetMakeupLipstick";
	elseif (makeupCat == "Face_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooFace"; elseif (makeupCat == "UpperBody_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooUB";
	modelDefs = {}; modelDefs.direction=IsoDirections.S; modelDefs.zoom=18; modelDefs.Yoffset=(-0.7);
	elseif (makeupCat == "LowerBody_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooLB"; modelDefs = {}; modelDefs.direction=IsoDirections.S; modelDefs.zoom=18; modelDefs.Yoffset=(-0.6);
	elseif (makeupCat == "Back_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooBack"; modelDefs = {}; modelDefs.direction=IsoDirections.N; modelDefs.zoom=18; modelDefs.Yoffset=(-0.7);
	elseif (makeupCat == "LeftArm_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooLA"; modelDefs = {}; modelDefs.direction=IsoDirections.W; modelDefs.zoom=19; modelDefs.Yoffset=(-0.6);
	elseif (makeupCat == "RightArm_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooRA"; modelDefs = {}; modelDefs.direction=IsoDirections.E; modelDefs.zoom=19; modelDefs.Yoffset=(-0.6);
	elseif (makeupCat == "LeftLeg_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooLL"; modelDefs = {}; modelDefs.direction=IsoDirections.W; modelDefs.zoom=19; modelDefs.Yoffset=(-0.3);
	elseif (makeupCat == "RightLeg_Tattoo") then self.resetSpecificButton.internal = "resetMakeupTattooRL"; modelDefs = {}; modelDefs.direction=IsoDirections.E; modelDefs.zoom=19; modelDefs.Yoffset=(-0.3);
	end

	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, makeupCat)
	if bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end

	self.character:setWornItem(makeup:getBodyLocation(), makeup);
	
	self.character:resetModel();
	sendVisual(self.character);
	if modelDefs and modelDefs.direction and modelDefs.zoom and modelDefs.Yoffset then
		self.playermodel:setDirection(modelDefs.direction)
		self.playermodel:setZoom(modelDefs.zoom)
		self.playermodel:setYOffset(modelDefs.Yoffset)
	end
	self.playermodel:setCharacter(self.character)

	self.resetSpecificButton:setEnable(true)
	self.resetAllButton:setEnable(true)
end

function LSMirrorMenu:onClickChangeHairPreview(button)
	local hairStyle = button.onClickArgs[1]
	local isBeard = button.onClickArgs[2]
	local idxStatic = button.onClickArgs[3]
	if not isBeard and not self.resetHairChange then self.resetHairChange = self.character:getHumanVisual():getHairModel(); end
	if isBeard and not self.resetBeardChange then self.resetBeardChange = self.character:getHumanVisual():getBeardModel(); end

	LMMHighlightBOSquare(idxStatic, self.menuSkin)

	if isBeard then
		self.character:getHumanVisual():setBeardModel(hairStyle);
		self.resetSpecificButton.internal = "resetBeardChange"
	else
		self.character:getHumanVisual():setHairModel(hairStyle);
		self.resetSpecificButton.internal = "resetHairChange"
	end

	self.character:resetModel();
	sendVisual(self.character);
	self.playermodel:setCharacter(self.character)

	self.resetSpecificButton:setEnable(true)
	self.resetAllButton:setEnable(true)
end

function LSMirrorMenu:onClickDyeHairPreview(button)
	local hairDye = button.onClickArgs[1]
	local isBeard = button.onClickArgs[2]
	local idxStatic = button.onClickArgs[3]
	if not isBeard and not self.resetHairColor then self.resetHairColor = self.character:getHumanVisual():getHairColor(); end
	if isBeard and not self.resetBeardColor then self.resetBeardColor = self.character:getHumanVisual():getBeardColor(); end

	LMMHighlightBOSquare(idxStatic, self.menuSkin)

	if isBeard then
		self.character:getHumanVisual():setBeardColor(ImmutableColor.new(hairDye:getFluidContainer():getColor():getR(), hairDye:getFluidContainer():getColor():getG(), hairDye:getFluidContainer():getColor():getB(), 1));
		self.beardDyeItem = hairDye
		self.resetSpecificButton.internal = "resetBeardColor"
	else
		self.character:getHumanVisual():setHairColor(ImmutableColor.new(hairDye:getFluidContainer():getColor():getR(), hairDye:getFluidContainer():getColor():getG(), hairDye:getFluidContainer():getColor():getB(), 1));
		self.hairDyeItem = hairDye
		self.resetSpecificButton.internal = "resetHairColor"
	end

	self.character:resetModel();
	sendVisual(self.character);
	self.playermodel:setCharacter(self.character)

	self.resetSpecificButton:setEnable(true)
	self.resetAllButton:setEnable(true)
end

local function LSMMdoImageType(x,y,w,h,texture)
	local newImage = ISImage:new(x, y, w, h, texture)
	return newImage
end

local function MMclearBottomOptions(menuSkin)
	for idx=1,8 do
		bottomMenuSqrList[idx].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQRH.png")
		bottomMenuModelList[idx]:setDirection(IsoDirections.S)
		bottomMenuModelList[idx]:setZoom(18)
		bottomMenuModelList[idx]:setYOffset(-0.9)
		bottomMenuModelList[idx]:setVisible(false)
		MMbottomMenuButtonList[idx]:setEnable(false)
	end
end

local function MMgetPageSelection(currentPage)
	local idxS, idxE
	idxE = 8*currentPage
	idxS = 1+(8*(currentPage-1))
	return idxS, idxE
end

local function MMgetMakeupBottomOptions(makeupTypeList, character, onClickMakeupPreview, page, makeupCat, modelDefs, menuSkin)

	local makeupItem, idxStart, idxEnd, previousMakeup, resetPlayerModel

	local bodyLocationItem = MMgetMakeupBodyLocationItem(character, makeupCat)

	if bodyLocationItem then previousMakeup = bodyLocationItem; end
	idxStart, idxEnd = MMgetPageSelection(page)

	if makeupTypeList and (#makeupTypeList == 1) then
		makeupItem = makeupTypeList[1].item
		bottomMenuSqrList[1].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")
		
		if previousMakeup then character:removeWornItem(previousMakeup); end
		local makeup = instanceItem(makeupItem)
		character:setWornItem(makeup:getBodyLocation(), makeup);
		previousMakeup = makeup

		character:resetModel();
		sendVisual(character);

		if modelDefs then
			bottomMenuModelList[1]:setDirection(modelDefs.direction)
			bottomMenuModelList[1]:setZoom(modelDefs.zoom)
			bottomMenuModelList[1]:setYOffset(modelDefs.Yoffset)
		end
		bottomMenuModelList[1]:setCharacter(character)
		bottomMenuModelList[1]:setVisible(true)
		
		MMbottomMenuButtonList[1]:setOnClick(onClickMakeupPreview, makeup, makeupCat, 1, false)
		MMbottomMenuButtonList[1]:setEnable(true)

	elseif makeupTypeList and (#makeupTypeList > 1) then
		local idxStatic = 0
		for idx, Type in ipairs(makeupTypeList) do
			if idx > idxEnd then break; end
			if idx >= idxStart then
				if previousMakeup then character:removeWornItem(previousMakeup); end
				makeupItem = Type.item
				idxStatic = idxStatic+1
				bottomMenuSqrList[idxStatic].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")

				local makeup = instanceItem(makeupItem)
				if makeup then
					if not resetPlayerModel then
						resetPlayerModel = character:getWornItem(makeup:getBodyLocation())
						if resetPlayerModel then character:removeWornItem(resetPlayerModel); end
					end
					character:setWornItem(makeup:getBodyLocation(), makeup);
					previousMakeup = makeup

					character:resetModel();
					sendVisual(character);
					if modelDefs then
						bottomMenuModelList[idxStatic]:setDirection(modelDefs.direction)
						bottomMenuModelList[idxStatic]:setZoom(modelDefs.zoom)
						bottomMenuModelList[idxStatic]:setYOffset(modelDefs.Yoffset)
					end
					bottomMenuModelList[idxStatic]:setCharacter(character)
					bottomMenuModelList[idxStatic]:setVisible(true)
					MMbottomMenuButtonList[idxStatic]:setOnClick(onClickMakeupPreview, makeup, makeupCat, idxStatic, false)
					MMbottomMenuButtonList[idxStatic]:setEnable(true)
				end
			end
		end
	else
		bottomMenuSqrList[1].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQRNO.png")
	end

	if makeupTypeList and (#makeupTypeList > 0) then
		if previousMakeup then
			character:removeWornItem(previousMakeup)
		end
		if bodyLocationItem then
			local newBodyLocationItem = MMgetMakeupBodyLocationItem(character, makeupCat)
			if newBodyLocationItem then character:removeWornItem(newBodyLocationItem); end
			character:setWornItem(bodyLocationItem:getBodyLocation(), bodyLocationItem);
			--print("MMgetMakeupBottomOptions: restoring original makeup")
		else
			--print("MMgetMakeupBottomOptions: no original makeup, keeping blank")
			--we run the loop again to ensure the makeup is gone
			bodyLocationItem = MMgetMakeupBodyLocationItem(character, makeupCat)
			if bodyLocationItem then character:removeWornItem(bodyLocationItem); end
		end
		character:resetModel();
		sendVisual(character);
	end
end

local function MMgetChangeHairBottomOptions(hairOrBeardList, character, onClickChangeHairPreview, page, isBeard, menuSkin)

	local hairStyle, idxStart, idxEnd
	local resetPlayerModel = character:getHumanVisual():getHairModel()
	if isBeard and character:isFemale() then
		hairOrBeardList = false
	elseif isBeard then
		resetPlayerModel = character:getHumanVisual():getBeardModel()
	end

	idxStart, idxEnd = MMgetPageSelection(page)

	if hairOrBeardList and (#hairOrBeardList == 1) then
		if hairOrBeardList[1] ~= "" then
			hairStyle = hairOrBeardList[1]:getName()
		else
			hairStyle = hairOrBeardList[1]
		end
		bottomMenuSqrList[1].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")
		if isBeard then
			character:getHumanVisual():setBeardModel(hairStyle);
		else
			character:getHumanVisual():setHairModel(hairStyle);
		end
		character:resetModel();
		sendVisual(character);
		bottomMenuModelList[1]:setCharacter(character)
		bottomMenuModelList[1]:setVisible(true)
		
		MMbottomMenuButtonList[1]:setOnClick(onClickChangeHairPreview, hairStyle, isBeard, 1, false)
		MMbottomMenuButtonList[1]:setEnable(true)

	elseif hairOrBeardList and (#hairOrBeardList > 1) then
		local idxStatic = 0
		for idx, Style in ipairs(hairOrBeardList) do
			if idx > idxEnd then break; end
			if idx >= idxStart then
				if Style ~= "" then
					hairStyle = Style:getName()
				else
					hairStyle = Style
				end
				idxStatic = idxStatic+1
				bottomMenuSqrList[idxStatic].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")
				if isBeard then
					character:getHumanVisual():setBeardModel(hairStyle);
				else
					character:getHumanVisual():setHairModel(hairStyle);
				end
				character:resetModel();
				sendVisual(character);
				bottomMenuModelList[idxStatic]:setCharacter(character)
				bottomMenuModelList[idxStatic]:setVisible(true)
				MMbottomMenuButtonList[idxStatic]:setOnClick(onClickChangeHairPreview, hairStyle, isBeard, idxStatic, false)
				MMbottomMenuButtonList[idxStatic]:setEnable(true)
			end
		end
	else
		bottomMenuSqrList[1].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQRNO.png")
	end

	if isBeard and hairOrBeardList and (#hairOrBeardList > 0) then
		character:getHumanVisual():setBeardModel(resetPlayerModel)
		character:resetModel();
		sendVisual(character);
	elseif hairOrBeardList and (#hairOrBeardList > 0) then
		character:getHumanVisual():setHairModel(resetPlayerModel)
		character:resetModel();
		sendVisual(character);
	end

end


local function MMgetDyeHairBottomOptions(itemsDyeList, character, onClickDyeHairPreview, page, isBeard, menuSkin)

	local dyeItem, idxStart, idxEnd
	local resetPlayerModel = character:getHumanVisual():getHairColor()
	local currentBeardStyle = getBeardStylesInstance():FindStyle(character:getHumanVisual():getBeardModel())
	if isBeard and (character:isFemale() or (not currentBeardStyle) or (currentBeardStyle and (currentBeardStyle:getLevel() < 1))) then
		itemsDyeList = false
	elseif isBeard then
		resetPlayerModel = character:getHumanVisual():getBeardColor()
	end

	idxStart, idxEnd = MMgetPageSelection(page)

	if itemsDyeList and (#itemsDyeList == 1) then
		dyeItem = itemsDyeList[1]
		bottomMenuSqrList[1].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")
		if isBeard then
			character:getHumanVisual():setBeardColor(ImmutableColor.new(dyeItem:getFluidContainer():getColor():getR(), dyeItem:getFluidContainer():getColor():getG(), dyeItem:getFluidContainer():getColor():getB(), 1));
		else
			character:getHumanVisual():setHairColor(ImmutableColor.new(dyeItem:getFluidContainer():getColor():getR(), dyeItem:getFluidContainer():getColor():getG(), dyeItem:getFluidContainer():getColor():getB(), 1));
		end
		character:resetModel();
		sendVisual(character);
		bottomMenuModelList[1]:setCharacter(character)
		bottomMenuModelList[1]:setVisible(true)
		
		MMbottomMenuButtonList[1]:setOnClick(onClickDyeHairPreview, dyeItem, isBeard, 1, false)
		MMbottomMenuButtonList[1]:setEnable(true)

	elseif itemsDyeList and (#itemsDyeList > 1) then
		local idxStatic = 0
		for idx, Item in ipairs(itemsDyeList) do
			if idx > idxEnd then break; end
			if idx >= idxStart then
				dyeItem = Item
				idxStatic = idxStatic+1
				bottomMenuSqrList[idxStatic].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQROFF.png")
				if isBeard then
					character:getHumanVisual():setBeardColor(ImmutableColor.new(dyeItem:getFluidContainer():getColor():getR(), dyeItem:getFluidContainer():getColor():getG(), dyeItem:getFluidContainer():getColor():getB(), 1));
				else
					character:getHumanVisual():setHairColor(ImmutableColor.new(dyeItem:getFluidContainer():getColor():getR(), dyeItem:getFluidContainer():getColor():getG(), dyeItem:getFluidContainer():getColor():getB(), 1));
				end
				character:resetModel();
				sendVisual(character);
				bottomMenuModelList[idxStatic]:setCharacter(character)
				bottomMenuModelList[idxStatic]:setVisible(true)
				MMbottomMenuButtonList[idxStatic]:setOnClick(onClickDyeHairPreview, dyeItem, isBeard, idxStatic, false)
				MMbottomMenuButtonList[idxStatic]:setEnable(true)
			end
		end
	else
		bottomMenuSqrList[1].texture = getTexture("media/textures/LSMM/"..menuSkin.."/LSMMSQRNO.png")
	end

	if isBeard and itemsDyeList and (#itemsDyeList > 0) then
		character:getHumanVisual():setBeardColor(resetPlayerModel)
		character:resetModel();
		sendVisual(character);
	elseif itemsDyeList and (#itemsDyeList > 0) then
		character:getHumanVisual():setHairColor(resetPlayerModel)
		character:resetModel();
		sendVisual(character);
	end

end

local function MMgetTotalPages(Table)

	local pageNumb = 1
	local getTotal = 0

	if Table and #Table > 8 then
		for idx, _ in ipairs(Table) do
			getTotal = getTotal+1
		end
		getTotal = math.ceil(getTotal/8)
		if getTotal < 1 then getTotal = 1; end
		pageNumb = getTotal
	end

	return pageNumb
end

local function MMgetIconItemTextureTooltip(Item, TextureOn, TextureOff, TooltipOn, TooltipOff)
	if Item then
		return TextureOn, TooltipOn
	end
	return TextureOff, TooltipOff
end

function LSMirrorMenu:onClickArrowDOWN(button)

	if (self.pagesTotal > 1) and (self.currentPage < self.pagesTotal) then
		self.currentPage = self.currentPage+1
		self.BOarrowUPButton:setEnable(true)
		if self.currentPage == self.pagesTotal then button:setEnable(false); end
		
		MMclearBottomOptions(self.menuSkin)
		if (button.internal == "Arrow_DyeHair") then MMgetDyeHairBottomOptions(self.itemsDyeList, self.character, self.onClickDyeHairPreview, self.currentPage, false, self.menuSkin); end
		if (button.internal == "Arrow_DyeBeard") then MMgetDyeHairBottomOptions(self.itemsDyeList, self.character, self.onClickDyeHairPreview, self.currentPage, true, self.menuSkin); end
		if (button.internal == "Arrow_HairstyleHair") then MMgetChangeHairBottomOptions(self.hairList, self.character, self.onClickChangeHairPreview, self.currentPage, false, self.menuSkin); end
		if (button.internal == "Arrow_HairstyleBeard") then MMgetChangeHairBottomOptions(self.beardList, self.character, self.onClickChangeHairPreview, self.currentPage, true, self.menuSkin); end	
		if (button.internal == "Arrow_MakeupFull") then MMgetMakeupBottomOptions(self.makeupList.fullface, self.character, self.onClickMakeupPreview, self.currentPage, "FullFace", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupEyes") then MMgetMakeupBottomOptions(self.makeupList.eyes, self.character, self.onClickMakeupPreview, self.currentPage, "Eyes", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupEyesShadow") then MMgetMakeupBottomOptions(self.makeupList.eyesshadow, self.character, self.onClickMakeupPreview, self.currentPage, "EyesShadow", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupLipstick") then MMgetMakeupBottomOptions(self.makeupList.lips, self.character, self.onClickMakeupPreview, self.currentPage, "Lips", false, self.menuSkin); end

		local modelDefs = {}
		if (button.internal == "Arrow_MakeupTatFace") then MMgetMakeupBottomOptions(self.makeupList.tatFace, self.character, self.onClickMakeupPreview, self.currentPage, "Face_Tattoo", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatUB") then modelDefs.direction=IsoDirections.S;modelDefs.zoom=18;modelDefs.Yoffset=(-0.7);
		MMgetMakeupBottomOptions(self.makeupList.tatUB, self.character, self.onClickMakeupPreview, self.currentPage, "UpperBody_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatLB") then modelDefs.direction=IsoDirections.S;modelDefs.zoom=18;modelDefs.Yoffset=(-0.6);
		MMgetMakeupBottomOptions(self.makeupList.tatLB, self.character, self.onClickMakeupPreview, self.currentPage, "LowerBody_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatBack") then modelDefs.direction=IsoDirections.N;modelDefs.zoom=18;modelDefs.Yoffset=(-0.7);
		MMgetMakeupBottomOptions(self.makeupList.tatBack, self.character, self.onClickMakeupPreview, self.currentPage, "Back_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatLA") then modelDefs.direction=IsoDirections.W;modelDefs.zoom=19;modelDefs.Yoffset=(-0.6);
		MMgetMakeupBottomOptions(self.makeupList.tatLA, self.character, self.onClickMakeupPreview, self.currentPage, "LeftArm_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatRA") then modelDefs.direction=IsoDirections.E;modelDefs.zoom=19;modelDefs.Yoffset=(-0.6);
		MMgetMakeupBottomOptions(self.makeupList.tatRA, self.character, self.onClickMakeupPreview, self.currentPage, "RightArm_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatLL") then modelDefs.direction=IsoDirections.W;modelDefs.zoom=19;modelDefs.Yoffset=(-0.3);
		MMgetMakeupBottomOptions(self.makeupList.tatLL, self.character, self.onClickMakeupPreview, self.currentPage, "LeftLeg_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatRL") then modelDefs.direction=IsoDirections.E;modelDefs.zoom=19;modelDefs.Yoffset=(-0.3);
		MMgetMakeupBottomOptions(self.makeupList.tatRL, self.character, self.onClickMakeupPreview, self.currentPage, "RightLeg_Tattoo", modelDefs, self.menuSkin); end
	end

end

function LSMirrorMenu:onClickArrowUP(button)

	if (self.pagesTotal > 1) and (self.currentPage > 1) then
		self.currentPage = self.currentPage-1
		self.BOarrowDownButton:setEnable(true)
		if self.currentPage == 1 then button:setEnable(false); end	

		MMclearBottomOptions(self.menuSkin)
		if (button.internal == "Arrow_DyeHair") then MMgetDyeHairBottomOptions(self.itemsDyeList, self.character, self.onClickDyeHairPreview, self.currentPage, false, self.menuSkin); end
		if (button.internal == "Arrow_DyeBeard") then MMgetDyeHairBottomOptions(self.itemsDyeList, self.character, self.onClickDyeHairPreview, self.currentPage, true, self.menuSkin); end
		if (button.internal == "Arrow_HairstyleHair") then MMgetChangeHairBottomOptions(self.hairList, self.character, self.onClickChangeHairPreview, self.currentPage, false, self.menuSkin); end
		if (button.internal == "Arrow_HairstyleBeard") then MMgetChangeHairBottomOptions(self.beardList, self.character, self.onClickChangeHairPreview, self.currentPage, true, self.menuSkin); end
		if (button.internal == "Arrow_MakeupFull") then MMgetMakeupBottomOptions(self.makeupList.fullface, self.character, self.onClickMakeupPreview, self.currentPage, "FullFace", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupEyes") then MMgetMakeupBottomOptions(self.makeupList.eyes, self.character, self.onClickMakeupPreview, self.currentPage, "Eyes", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupEyesShadow") then MMgetMakeupBottomOptions(self.makeupList.eyesshadow, self.character, self.onClickMakeupPreview, self.currentPage, "EyesShadow", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupLipstick") then MMgetMakeupBottomOptions(self.makeupList.lips, self.character, self.onClickMakeupPreview, self.currentPage, "Lips", false, self.menuSkin); end

		local modelDefs = {}
		if (button.internal == "Arrow_MakeupTatFace") then MMgetMakeupBottomOptions(self.makeupList.tatFace, self.character, self.onClickMakeupPreview, self.currentPage, "Face_Tattoo", false, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatUB") then modelDefs.direction=IsoDirections.S;modelDefs.zoom=18;modelDefs.Yoffset=(-0.7);
		MMgetMakeupBottomOptions(self.makeupList.tatUB, self.character, self.onClickMakeupPreview, self.currentPage, "UpperBody_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatLB") then modelDefs.direction=IsoDirections.S;modelDefs.zoom=18;modelDefs.Yoffset=(-0.6);
		MMgetMakeupBottomOptions(self.makeupList.tatLB, self.character, self.onClickMakeupPreview, self.currentPage, "LowerBody_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatBack") then modelDefs.direction=IsoDirections.N;modelDefs.zoom=18;modelDefs.Yoffset=(-0.7);
		MMgetMakeupBottomOptions(self.makeupList.tatBack, self.character, self.onClickMakeupPreview, self.currentPage, "Back_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatLA") then modelDefs.direction=IsoDirections.W;modelDefs.zoom=19;modelDefs.Yoffset=(-0.6);
		MMgetMakeupBottomOptions(self.makeupList.tatLA, self.character, self.onClickMakeupPreview, self.currentPage, "LeftArm_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatRA") then modelDefs.direction=IsoDirections.E;modelDefs.zoom=19;modelDefs.Yoffset=(-0.6);
		MMgetMakeupBottomOptions(self.makeupList.tatRA, self.character, self.onClickMakeupPreview, self.currentPage, "RightArm_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatLL") then modelDefs.direction=IsoDirections.W;modelDefs.zoom=19;modelDefs.Yoffset=(-0.3);
		MMgetMakeupBottomOptions(self.makeupList.tatLL, self.character, self.onClickMakeupPreview, self.currentPage, "LeftLeg_Tattoo", modelDefs, self.menuSkin); end
		if (button.internal == "Arrow_MakeupTatRL") then modelDefs.direction=IsoDirections.E;modelDefs.zoom=19;modelDefs.Yoffset=(-0.3);
		MMgetMakeupBottomOptions(self.makeupList.tatRL, self.character, self.onClickMakeupPreview, self.currentPage, "RightLeg_Tattoo", modelDefs, self.menuSkin); end

	end

end

local function MMclearMirrorCircleSub(circleList, menuSkin)

	for _, circleOption in pairs(circleList) do
		circleOption:setEnable(false)
		circleOption:setImage(getTexture("media/textures/LSMM/"..menuSkin.."/LSMM_MOH.png"))
		circleOption.internal = "None"
	end

end

function LSMirrorMenu:onClickCircleMakeupTattoosSub(button)

	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)

    if button.internal == "MOTatLA" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLAOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatUBOff.png"))
		self.LSMirrorMenuOptionCircleRightLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatRAOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooLA"
		if (self.resetMakeupTattooLA ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "LeftArm_Tattoo"
		end
		----ModelDefs
		local modelDefs = {}; modelDefs.direction=IsoDirections.W;modelDefs.zoom=19;modelDefs.Yoffset=(-0.6)
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatLA)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatLA"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatLA"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatLA, self.character, self.onClickMakeupPreview, 1, "LeftArm_Tattoo", modelDefs, self.menuSkin)
	elseif button.internal == "MOTatRA" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatRAOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatUBOff.png"))
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLAOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooRA"
		if (self.resetMakeupTattooRA ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "RightArm_Tattoo"
		end
		----ModelDefs
		local modelDefs = {}; modelDefs.direction=IsoDirections.E;modelDefs.zoom=19;modelDefs.Yoffset=(-0.6)
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatRA)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatRA"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatRA"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatRA, self.character, self.onClickMakeupPreview, 1, "RightArm_Tattoo", modelDefs, self.menuSkin)
	elseif button.internal == "MOTatLL" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLLOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLBOff.png"))
		self.LSMirrorMenuOptionCircleRightLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatRLOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooLL"
		if (self.resetMakeupTattooLL ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "LeftLeg_Tattoo"
		end
		----ModelDefs
		local modelDefs = {}; modelDefs.direction=IsoDirections.W;modelDefs.zoom=19;modelDefs.Yoffset=(-0.3)
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatLL)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatLL"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatLL"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatLL, self.character, self.onClickMakeupPreview, 1, "LeftLeg_Tattoo", modelDefs, self.menuSkin)
	elseif button.internal == "MOTatRL" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatRLOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLBOff.png"))
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLLOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooRL"
		if (self.resetMakeupTattooRL ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "RightLeg_Tattoo"
		end
		----ModelDefs
		local modelDefs = {}; modelDefs.direction=IsoDirections.E;modelDefs.zoom=19;modelDefs.Yoffset=(-0.3)
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatRL)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatRL"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatRL"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatRL, self.character, self.onClickMakeupPreview, 1, "RightLeg_Tattoo", modelDefs, self.menuSkin)
    end

end


function LSMirrorMenu:onClickCircleMakeupTattoos(button)

	MMclearMirrorCircleSub(MMcircleSubList, self.menuSkin)
	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)

    if button.internal == "MOTatFace" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatFaceOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatUBOff.png"))
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLBOff.png"))
		self.LSMirrorMenuOptionCircleBackTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatBackOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooFace"
		if (self.resetMakeupTattooFace ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "Face_Tattoo"
		end
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatFace)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatFace"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatFace"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatFace, self.character, self.onClickMakeupPreview, 1, "Face_Tattoo", false, self.menuSkin)
	elseif button.internal == "MOTatUB" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatUBOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleFaceTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatFaceOff.png"))
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLBOff.png"))
		self.LSMirrorMenuOptionCircleBackTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatBackOff.png"))
		----SmallCircles
		self.LSMirrorMenuOptionCircleLeftLegTattoos.internal = "MOTatLA"
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setOnClick(self.onClickCircleMakeupTattoosSub, false, false, false, false)
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setEnable(true)
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLAOff.png"))
		self.LSMirrorMenuOptionCircleRightLegTattoos.internal = "MOTatRA"
		self.LSMirrorMenuOptionCircleRightLegTattoos:setOnClick(self.onClickCircleMakeupTattoosSub, false, false, false, false)
		self.LSMirrorMenuOptionCircleRightLegTattoos:setEnable(true)
		self.LSMirrorMenuOptionCircleRightLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatRAOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooUB"
		if (self.resetMakeupTattooUB ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "UpperBody_Tattoo"
		end
		----ModelDefs
		local modelDefs = {}; modelDefs.direction=IsoDirections.S;modelDefs.zoom=18;modelDefs.Yoffset=(-0.7)
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatUB)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatUB"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatUB"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatUB, self.character, self.onClickMakeupPreview, 1, "UpperBody_Tattoo", modelDefs, self.menuSkin)
	elseif button.internal == "MOTatLB" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLBOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleFaceTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatFaceOff.png"))
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatUBOff.png"))
		self.LSMirrorMenuOptionCircleBackTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatBackOff.png"))
		----SmallCircles
		self.LSMirrorMenuOptionCircleLeftLegTattoos.internal = "MOTatLL"
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setOnClick(self.onClickCircleMakeupTattoosSub, false, false, false, false)
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setEnable(true)
		self.LSMirrorMenuOptionCircleLeftLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLLOff.png"))
		self.LSMirrorMenuOptionCircleRightLegTattoos.internal = "MOTatRL"
		self.LSMirrorMenuOptionCircleRightLegTattoos:setOnClick(self.onClickCircleMakeupTattoosSub, false, false, false, false)
		self.LSMirrorMenuOptionCircleRightLegTattoos:setEnable(true)
		self.LSMirrorMenuOptionCircleRightLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatRLOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooLB"
		if (self.resetMakeupTattooLB ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "LowerBody_Tattoo"
		end
		----ModelDefs
		local modelDefs = {}; modelDefs.direction=IsoDirections.S;modelDefs.zoom=18;modelDefs.Yoffset=(-0.6)
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatLB)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatLB"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatLB"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatLB, self.character, self.onClickMakeupPreview, 1, "LowerBody_Tattoo", modelDefs, self.menuSkin)
	elseif button.internal == "MOTatBack" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatBackOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleFaceTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatFaceOff.png"))
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatUBOff.png"))
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLBOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooBack"
		if (self.resetMakeupTattooBack ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "Back_Tattoo"
		end
		----ModelDefs
		local modelDefs = {}; modelDefs.direction=IsoDirections.N;modelDefs.zoom=18;modelDefs.Yoffset=(-0.7)
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatBack)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatBack"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatBack"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.tatBack, self.character, self.onClickMakeupPreview, 1, "Back_Tattoo", modelDefs, self.menuSkin)
    end

end

function LSMirrorMenu:onClickCircleMakeupEyes(button)

	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"

    if button.internal == "MOEyesEye" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_EyeBrushOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_EyelinerOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupEye"
		if (self.resetMakeupEye ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		self.removeMakeupButton:setEnable(true)
		self.removeMakeupButton.internal = "Eyes"
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.eyes)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupEyes"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupEyes"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.eyes, self.character, self.onClickMakeupPreview, 1, "Eyes", false, self.menuSkin)
	elseif button.internal == "MOEyesShadow" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_EyelinerOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_EyeBrushOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupEyeShadow"
		if (self.resetMakeupEyeShadow ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		self.removeMakeupButton:setEnable(true)
		self.removeMakeupButton.internal = "EyesShadow"
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.eyesshadow)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupEyesShadow"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupEyesShadow"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetMakeupBottomOptions(self.makeupList.eyesshadow, self.character, self.onClickMakeupPreview, 1, "EyesShadow", false, self.menuSkin)
    end

end

function LSMirrorMenu:onClickCircleHairChange(button)

	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"

    if button.internal == "MOHSHair" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_HairOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_BeardOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetHairChange"
		if self.resetHairChange then self.resetSpecificButton:setEnable(true); end
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.hairList)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_HairstyleHair"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_HairstyleHair"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetChangeHairBottomOptions(self.hairList, self.character, self.onClickChangeHairPreview, 1, false, self.menuSkin)
	elseif button.internal == "MOHSBeard" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_BeardOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_HairOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetBeardChange"
		if self.resetBeardChange then self.resetSpecificButton:setEnable(true); end
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.beardList)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_HairstyleBeard"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_HairstyleBeard"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetChangeHairBottomOptions(self.beardList, self.character, self.onClickChangeHairPreview, 1, true, self.menuSkin)
    end

end

function LSMirrorMenu:onClickCircleColor(button)

	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"

    if button.internal == "MODCHair" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_HairOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_BeardOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetHairColor"
		if self.resetHairColor then self.resetSpecificButton:setEnable(true); end
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.itemsDyeList)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_DyeHair"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_DyeHair"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetDyeHairBottomOptions(self.itemsDyeList, self.character, self.onClickDyeHairPreview, 1, false, self.menuSkin)
	elseif button.internal == "MODCBeard" then
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_BeardOn.png"))
		-----Circles
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_HairOff.png"))
		-----Reset
		self.resetSpecificButton.internal = "resetBeardColor"
		if self.resetBeardColor then self.resetSpecificButton:setEnable(true); end
		-----BottomOptions
		---beardException
		local currentBeardStyle = getBeardStylesInstance():FindStyle(self.character:getHumanVisual():getBeardModel())
		if (self.character:isFemale() or (not currentBeardStyle) or (currentBeardStyle and (currentBeardStyle:getLevel() < 1))) then
			self.pagesTotal = 1
		else
			self.pagesTotal = MMgetTotalPages(self.itemsDyeList)
		end
		--
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_DyeBeard"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_DyeBeard"; end
		MMclearBottomOptions(self.menuSkin)
		MMgetDyeHairBottomOptions(self.itemsDyeList, self.character, self.onClickDyeHairPreview, 1, true, self.menuSkin)
    end

end

local function MMclearMirrorSettings(exception, menuList, circleList, menuSkin)

	for k, v in pairs(menuList) do
		if (v.internal ~= exception) and (v.option.internal == v.internal) then
			v.option:setImage(getTexture("media/textures/LSMM/"..menuSkin.."/LSMM_MO_"..v.tex..".png"))
			v.option.internal = v.off
		end
	end

	for _, circleOption in pairs(circleList) do
		circleOption:setEnable(false)
		circleOption:setImage(getTexture("media/textures/LSMM/"..menuSkin.."/LSMM_MOH.png"))
		circleOption.internal = "None"
	end

end

function LSMirrorMenu:onClickMakeupTattoosOption(button)

--first we clear any previous settings
	MMclearMirrorSettings("MOMakeupTattoosOn", MMmenuList, MMcircleList, self.menuSkin)
	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.removeMakeupButton:setEnable(false)
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)
	MMclearBottomOptions(self.menuSkin)

--then proceed
	if button.internal == "MOMakeupTattoosOff" then
		--LSMMresetMenuOptions(self.)
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupTattoosOn.png"))
		button.internal = "MOMakeupTattoosOn"
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupTattooFace"
		if (self.resetMakeupTattooFace ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		if self.itemsList.MakeupTattooBrush then
			self.removeMakeupButton:setEnable(true)
			self.removeMakeupButton.internal = "Face_Tattoo"
		end
		-----Circles
		self.LSMirrorMenuOptionCircleHair.internal = "MOTatUB"
		self.LSMirrorMenuOptionCircleHair:setOnClick(self.onClickCircleMakeupTattoos, false, false, false, false)
		self.LSMirrorMenuOptionCircleHair:setEnable(true)
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatUBOff.png"))
		self.LSMirrorMenuOptionCircleBeard.internal = "MOTatLB"
		self.LSMirrorMenuOptionCircleBeard:setOnClick(self.onClickCircleMakeupTattoos, false, false, false, false)
		self.LSMirrorMenuOptionCircleBeard:setEnable(true)
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatLBOff.png"))
		self.LSMirrorMenuOptionCircleFaceTattoos.internal = "MOTatFace"
		self.LSMirrorMenuOptionCircleFaceTattoos:setOnClick(self.onClickCircleMakeupTattoos, false, false, false, false)
		self.LSMirrorMenuOptionCircleFaceTattoos:setEnable(true)
		self.LSMirrorMenuOptionCircleFaceTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatFaceOn.png"))
		self.LSMirrorMenuOptionCircleBackTattoos.internal = "MOTatBack"
		self.LSMirrorMenuOptionCircleBackTattoos:setOnClick(self.onClickCircleMakeupTattoos, false, false, false, false)
		self.LSMirrorMenuOptionCircleBackTattoos:setEnable(true)
		self.LSMirrorMenuOptionCircleBackTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_TatBackOff.png"))
		
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.tatFace)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupTatFace"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupTatFace"; end
		MMgetMakeupBottomOptions(self.makeupList.tatFace, self.character, self.onClickMakeupPreview, 1, "Face_Tattoo", false, self.menuSkin)
	elseif button.internal == "MOMakeupTattoosOn" then--last we set the button from this function off in case it was on
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupTattoosOff.png"))
		button.internal = "MOMakeupTattoosOff"
    end

end

function LSMirrorMenu:onClickMakeupLipsOption(button)

--first we clear any previous settings
	MMclearMirrorSettings("MOMakeupLipsOn", MMmenuList, MMcircleList, self.menuSkin)
	--if self.LSMirrorMenuOptionDye.internal == "MODyeOn" then self.LSMirrorMenuOptionDye:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOff.png")); self.LSMirrorMenuOptionDye.internal = "MODyeOff"; end
	--if self.LSMirrorMenuOptionHairstyle.internal == "MOHairstyleOn" then self.LSMirrorMenuOptionHairstyle:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_HairstyleOff.png")); self.LSMirrorMenuOptionHairstyle.internal = "MOHairstyleOff"; end
	--if self.LSMirrorMenuOptionMakeupEyes.internal == "MOMakeupEyesOn" then self.LSMirrorMenuOptionMakeupEyes:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupEyesOff.png")); self.LSMirrorMenuOptionMakeupEyes.internal = "MOMakeupEyesOff"; end
	--if self.LSMirrorMenuOptionMakeupFull.internal == "MOMakeupFullOn" then self.LSMirrorMenuOptionMakeupFull:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupFullOff.png")); self.LSMirrorMenuOptionMakeupFull.internal = "MOMakeupFullOff"; end	
	--self.LSMirrorMenuOptionCircleHair:setEnable(false)
	--self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleHair.internal = "None"
	--self.LSMirrorMenuOptionCircleBeard:setEnable(false)
	--self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleBeard.internal = "None"
	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.removeMakeupButton:setEnable(false)
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)
	MMclearBottomOptions(self.menuSkin)

--then proceed
	if button.internal == "MOMakeupLipsOff" then
		--LSMMresetMenuOptions(self.)
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupLipsOn.png"))
		button.internal = "MOMakeupLipsOn"
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupLipstick"
		if (self.resetMakeupLipstick ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		self.removeMakeupButton:setEnable(true)
		self.removeMakeupButton.internal = "Lips"
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.lips)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupLipstick"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupLipstick"; end
		MMgetMakeupBottomOptions(self.makeupList.lips, self.character, self.onClickMakeupPreview, 1, "Lips", false, self.menuSkin)
	elseif button.internal == "MOMakeupLipsOn" then--last we set the button from this function off in case it was on
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupLipsOff.png"))
		button.internal = "MOMakeupLipsOff"
    end

end

function LSMirrorMenu:onClickMakeupEyesOption(button)

--first we clear any previous settings
	MMclearMirrorSettings("MOMakeupEyesOn", MMmenuList, MMcircleList, self.menuSkin)
	--if self.LSMirrorMenuOptionDye.internal == "MODyeOn" then self.LSMirrorMenuOptionDye:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOff.png")); self.LSMirrorMenuOptionDye.internal = "MODyeOff"; end
	--if self.LSMirrorMenuOptionHairstyle.internal == "MOHairstyleOn" then self.LSMirrorMenuOptionHairstyle:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_HairstyleOff.png")); self.LSMirrorMenuOptionHairstyle.internal = "MOHairstyleOff"; end
	--if self.LSMirrorMenuOptionMakeupFull.internal == "MOMakeupFullOn" then self.LSMirrorMenuOptionMakeupFull:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupFullOff.png")); self.LSMirrorMenuOptionMakeupFull.internal = "MOMakeupFullOff"; end
	--if self.LSMirrorMenuOptionMakeupLips.internal == "MOMakeupLipsOn" then self.LSMirrorMenuOptionMakeupLips:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupLipsOff.png")); self.LSMirrorMenuOptionMakeupLips.internal = "MOMakeupLipsOff"; end
	--self.LSMirrorMenuOptionCircleHair:setEnable(false)
	--self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleHair.internal = "None"
	--self.LSMirrorMenuOptionCircleBeard:setEnable(false)
	--self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleBeard.internal = "None"
	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.removeMakeupButton:setEnable(false)
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)
	MMclearBottomOptions(self.menuSkin)

--then proceed
	if button.internal == "MOMakeupEyesOff" then
		--LSMMresetMenuOptions(self.)
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupEyesOn.png"))
		button.internal = "MOMakeupEyesOn"
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupEye"
		if (self.resetMakeupEye ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		self.removeMakeupButton:setEnable(true)
		self.removeMakeupButton.internal = "Eyes"
		-----Circles
		self.LSMirrorMenuOptionCircleHair.internal = "MOEyesEye"
		self.LSMirrorMenuOptionCircleHair:setOnClick(self.onClickCircleMakeupEyes, false, false, false, false)
		self.LSMirrorMenuOptionCircleHair:setEnable(true)
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_EyeBrushOn.png"))
		self.LSMirrorMenuOptionCircleBeard.internal = "MOEyesShadow"
		self.LSMirrorMenuOptionCircleBeard:setOnClick(self.onClickCircleMakeupEyes, false, false, false, false)
		self.LSMirrorMenuOptionCircleBeard:setEnable(true)
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_EyelinerOff.png"))
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.eyes)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupEyes"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupEyes"; end
		MMgetMakeupBottomOptions(self.makeupList.eyes, self.character, self.onClickMakeupPreview, 1, "Eyes", false, self.menuSkin)
	elseif button.internal == "MOMakeupEyesOn" then--last we set the button from this function off in case it was on
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupEyesOff.png"))
		button.internal = "MOMakeupEyesOff"
    end

end

function LSMirrorMenu:onClickMakeupFullOption(button)

--first we clear any previous settings
	MMclearMirrorSettings("MOMakeupFullOn", MMmenuList, MMcircleList, self.menuSkin)
	--if self.LSMirrorMenuOptionDye.internal == "MODyeOn" then self.LSMirrorMenuOptionDye:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOff.png")); self.LSMirrorMenuOptionDye.internal = "MODyeOff"; end
	--if self.LSMirrorMenuOptionHairstyle.internal == "MOHairstyleOn" then self.LSMirrorMenuOptionHairstyle:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_HairstyleOff.png")); self.LSMirrorMenuOptionHairstyle.internal = "MOHairstyleOff"; end
	--if self.LSMirrorMenuOptionMakeupEyes.internal == "MOMakeupEyesOn" then self.LSMirrorMenuOptionMakeupEyes:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupEyesOff.png")); self.LSMirrorMenuOptionMakeupEyes.internal = "MOMakeupEyesOff"; end
	--if self.LSMirrorMenuOptionMakeupLips.internal == "MOMakeupLipsOn" then self.LSMirrorMenuOptionMakeupLips:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupLipsOff.png")); self.LSMirrorMenuOptionMakeupLips.internal = "MOMakeupLipsOff"; end
	--self.LSMirrorMenuOptionCircleHair:setEnable(false)
	--self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleHair.internal = "None"
	--self.LSMirrorMenuOptionCircleBeard:setEnable(false)
	--self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleBeard.internal = "None"
	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.removeMakeupButton:setEnable(false)
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)
	MMclearBottomOptions(self.menuSkin)

--then proceed
	if button.internal == "MOMakeupFullOff" then
		--LSMMresetMenuOptions(self.)
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupFullOn.png"))
		button.internal = "MOMakeupFullOn"
		-----Reset
		self.resetSpecificButton.internal = "resetMakeupFull"
		if (self.resetMakeupFull ~= 0) then self.resetSpecificButton:setEnable(true); end
		----Erase
		self.removeMakeupButton:setEnable(true)
		self.removeMakeupButton.internal = "FullFace"
		-----Circles
		--self.LSMirrorMenuOptionCircleHair.internal = "MOHSHair"
		--self.LSMirrorMenuOptionCircleHair:setOnClick(self.onClickCircleHairChange, false, false, false, false)
		--self.LSMirrorMenuOptionCircleHair:setEnable(true)
		--self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_HairOn.png"))
		--self.LSMirrorMenuOptionCircleBeard.internal = "MOHSBeard"
		--self.LSMirrorMenuOptionCircleBeard:setOnClick(self.onClickCircleHairChange, false, false, false, false)
		--self.LSMirrorMenuOptionCircleBeard:setEnable(true)
		--self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_BeardOff.png"))
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.makeupList.fullface)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_MakeupFull"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_MakeupFull"; end
		MMgetMakeupBottomOptions(self.makeupList.fullface, self.character, self.onClickMakeupPreview, 1, "FullFace", false, self.menuSkin)
	elseif button.internal == "MOMakeupFullOn" then--last we set the button from this function off in case it was on
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupFullOff.png"))
		button.internal = "MOMakeupFullOff"
    end

end

function LSMirrorMenu:onClickHairstyleOption(button)

--first we clear any previous settings
	MMclearMirrorSettings("MOHairstyleOn", MMmenuList, MMcircleList, self.menuSkin)
	--if self.LSMirrorMenuOptionDye.internal == "MODyeOn" then self.LSMirrorMenuOptionDye:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOff.png")); self.LSMirrorMenuOptionDye.internal = "MODyeOff"; end
	--if self.LSMirrorMenuOptionMakeupFull.internal == "MOMakeupFullOn" then self.LSMirrorMenuOptionMakeupFull:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupFullOff.png")); self.LSMirrorMenuOptionMakeupFull.internal = "MOMakeupFullOff"; end	
	--if self.LSMirrorMenuOptionMakeupEyes.internal == "MOMakeupEyesOn" then self.LSMirrorMenuOptionMakeupEyes:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupEyesOff.png")); self.LSMirrorMenuOptionMakeupEyes.internal = "MOMakeupEyesOff"; end
	--if self.LSMirrorMenuOptionMakeupLips.internal == "MOMakeupLipsOn" then self.LSMirrorMenuOptionMakeupLips:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupLipsOff.png")); self.LSMirrorMenuOptionMakeupLips.internal = "MOMakeupLipsOff"; end
	--self.LSMirrorMenuOptionCircleHair:setEnable(false)
	--self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleHair.internal = "None"
	--self.LSMirrorMenuOptionCircleBeard:setEnable(false)
	--self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleBeard.internal = "None"
	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.removeMakeupButton:setEnable(false)
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)
	MMclearBottomOptions(self.menuSkin)

--then proceed
	if button.internal == "MOHairstyleOff" then
		--LSMMresetMenuOptions(self.)
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_HairstyleOn.png"))
		button.internal = "MOHairstyleOn"
		-----Reset
		self.resetSpecificButton.internal = "resetHairstyleHair"
		if self.resetHairColor then self.resetSpecificButton:setEnable(true); end
		-----Circles
		self.LSMirrorMenuOptionCircleHair.internal = "MOHSHair"
		self.LSMirrorMenuOptionCircleHair:setOnClick(self.onClickCircleHairChange, false, false, false, false)
		self.LSMirrorMenuOptionCircleHair:setEnable(true)
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_HairOn.png"))
		self.LSMirrorMenuOptionCircleBeard.internal = "MOHSBeard"
		self.LSMirrorMenuOptionCircleBeard:setOnClick(self.onClickCircleHairChange, false, false, false, false)
		self.LSMirrorMenuOptionCircleBeard:setEnable(true)
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_BeardOff.png"))
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.hairList)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_HairstyleHair"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_HairstyleHair"; end
		
		MMgetChangeHairBottomOptions(self.hairList, self.character, self.onClickChangeHairPreview, 1, false, self.menuSkin)
	elseif button.internal == "MOHairstyleOn" then--last we set the button from this function off in case it was on
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_HairstyleOff.png"))
		button.internal = "MOHairstyleOff"
    end

end



function LSMirrorMenu:onClickDyeOption(button)

--first we clear any previous settings
	
	MMclearMirrorSettings("MODyeOn", MMmenuList, MMcircleList, self.menuSkin)
	--if self.LSMirrorMenuOptionHairstyle.internal == "MOHairstyleOn" then self.LSMirrorMenuOptionHairstyle:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_HairstyleOff.png")); self.LSMirrorMenuOptionHairstyle.internal = "MOHairstyleOff"; end
	--if self.LSMirrorMenuOptionMakeupFull.internal == "MOMakeupFullOn" then self.LSMirrorMenuOptionMakeupFull:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupFullOff.png")); self.LSMirrorMenuOptionMakeupFull.internal = "MOMakeupFullOff"; end	
	--if self.LSMirrorMenuOptionMakeupEyes.internal == "MOMakeupEyesOn" then self.LSMirrorMenuOptionMakeupEyes:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupEyesOff.png")); self.LSMirrorMenuOptionMakeupEyes.internal = "MOMakeupEyesOff"; end
	--if self.LSMirrorMenuOptionMakeupLips.internal == "MOMakeupLipsOn" then self.LSMirrorMenuOptionMakeupLips:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupLipsOff.png")); self.LSMirrorMenuOptionMakeupLips.internal = "MOMakeupLipsOff"; end
	--if self.LSMirrorMenuOptionTattoos.internal == "MOMakeupTattoosOn" then self.LSMirrorMenuOptionTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupTattoosOff.png")); self.LSMirrorMenuOptionTattoos.internal = "MOMakeupTattoosOff"; end
	--self.LSMirrorMenuOptionCircleHair:setEnable(false)
	--self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleHair.internal = "None"
	--self.LSMirrorMenuOptionCircleBeard:setEnable(false)
	--self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	--self.LSMirrorMenuOptionCircleBeard.internal = "None"
	self.pagesTotal = 1
	self.currentPage = 1
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.internal = "UP"
	self.resetSpecificButton:setEnable(false)
	self.resetSpecificButton.internal = "resetNone"
	self.removeMakeupButton:setEnable(false)
	self.playermodel:setDirection(IsoDirections.S); self.playermodel:setZoom(18); self.playermodel:setYOffset(-0.9)
	MMclearBottomOptions(self.menuSkin)

--then proceed
	if button.internal == "MODyeOff" then
		--LSMMresetMenuOptions(self.)
		-----Button
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOn.png"))
		button.internal = "MODyeOn"
		-----Reset
		self.resetSpecificButton.internal = "resetHairColor"
		if self.resetHairColor then self.resetSpecificButton:setEnable(true); end
		-----Circles
		self.LSMirrorMenuOptionCircleHair.internal = "MODCHair"
		self.LSMirrorMenuOptionCircleHair:setOnClick(self.onClickCircleColor, false, false, false, false)
		self.LSMirrorMenuOptionCircleHair:setEnable(true)
		self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_HairOn.png"))
		self.LSMirrorMenuOptionCircleBeard.internal = "MODCBeard"
		self.LSMirrorMenuOptionCircleBeard:setOnClick(self.onClickCircleColor, false, false, false, false)
		self.LSMirrorMenuOptionCircleBeard:setEnable(true)
		self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOC_BeardOff.png"))
		-----BottomOptions
		self.pagesTotal = MMgetTotalPages(self.itemsDyeList)
		if self.pagesTotal > 1 then self.BOarrowDownButton.internal="Arrow_DyeHair"; self.BOarrowDownButton:setEnable(true); self.BOarrowUPButton.internal="Arrow_DyeHair"; end
		
		MMgetDyeHairBottomOptions(self.itemsDyeList, self.character, self.onClickDyeHairPreview, 1, false, self.menuSkin)
	elseif button.internal == "MODyeOn" then--last we set the button from this function off in case it was on
		button:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOff.png"))
		button.internal = "MODyeOff"
    end

end

function LSMirrorMenu:onClick(button)

    if button.internal == "Close" then
        self:close();
	end

end

function LSMirrorMenu:onMenuSkinComboSelected(combo)
	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer then
		specificPlayer:getModData().LSMirrorMenuOverlayPanelSkin = combo:getOptionData(combo.selected)
		specificPlayer:getModData().LSMirrorMenuOverlayPanel = "changeSkin"
	else
		return
	end
	self:close();
end

function LSMirrorMenu:initialise()
	local fnt_height = getTextManager():MeasureFont(self.font);
	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer and specificPlayer:getModData().LSMirrorMenuOverlayPanelSkin and tostring(specificPlayer:getModData().LSMirrorMenuOverlayPanelSkin) then
		self.menuSkin = specificPlayer:getModData().LSMirrorMenuOverlayPanelSkin
	end

	self.offset_x = 0
	self.offset_y = fnt_height/2

	self.LSMirrorBackgroundImage = LSMMdoImageType(0,0,self:getWidth(),self:getHeight(),getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMMBKG.png"))
	self.LSMirrorBackgroundImage:initialise()
	self:addChild(self.LSMirrorBackgroundImage)

	---SIDE OPTIONS
	self.LSMirrorMenuOptionDye = ISButton:new(350, 100, 43, 43, "", self, self.onClickDyeOption)
	self.LSMirrorMenuOptionDye.internal = "MODyeOff"
	self.LSMirrorMenuOptionDye.displayBackground = false
	self.LSMirrorMenuOptionDye.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionDye:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOff.png"))
	self.LSMirrorMenuOptionDye:initialise()
	self.LSMirrorMenuOptionDye:instantiate()
	self:addChild(self.LSMirrorMenuOptionDye)

	self.LSMirrorMenuOptionHairstyle = ISButton:new(350, 143, 43, 43, "", self, self.onClickHairstyleOption)
	self.LSMirrorMenuOptionHairstyle.internal = "MOHairstyleOff"
	self.LSMirrorMenuOptionHairstyle.displayBackground = false
	self.LSMirrorMenuOptionHairstyle.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionHairstyle:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_HairstyleOff.png"))
	self.LSMirrorMenuOptionHairstyle:initialise()
	self.LSMirrorMenuOptionHairstyle:instantiate()
	self:addChild(self.LSMirrorMenuOptionHairstyle)

	self.LSMirrorMenuOptionMakeupFull = ISButton:new(350, 186, 43, 43, "", self, self.onClickMakeupFullOption)
	self.LSMirrorMenuOptionMakeupFull.internal = "MOMakeupFullOff"
	self.LSMirrorMenuOptionMakeupFull.displayBackground = false
	self.LSMirrorMenuOptionMakeupFull.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionMakeupFull:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupFullOff.png"))
	self.LSMirrorMenuOptionMakeupFull:initialise()
	self.LSMirrorMenuOptionMakeupFull:instantiate()
	self:addChild(self.LSMirrorMenuOptionMakeupFull)

	self.LSMirrorMenuOptionMakeupEyes = ISButton:new(350, 229, 43, 43, "", self, self.onClickMakeupEyesOption)
	self.LSMirrorMenuOptionMakeupEyes.internal = "MOMakeupEyesOff"
	self.LSMirrorMenuOptionMakeupEyes.displayBackground = false
	self.LSMirrorMenuOptionMakeupEyes.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionMakeupEyes:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupEyesOff.png"))
	self.LSMirrorMenuOptionMakeupEyes:initialise()
	self.LSMirrorMenuOptionMakeupEyes:instantiate()
	self:addChild(self.LSMirrorMenuOptionMakeupEyes)

	self.LSMirrorMenuOptionMakeupLips = ISButton:new(350, 272, 43, 43, "", self, self.onClickMakeupLipsOption)
	self.LSMirrorMenuOptionMakeupLips.internal = "MOMakeupLipsOff"
	self.LSMirrorMenuOptionMakeupLips.displayBackground = false
	self.LSMirrorMenuOptionMakeupLips.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionMakeupLips:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupLipsOff.png"))
	self.LSMirrorMenuOptionMakeupLips:initialise()
	self.LSMirrorMenuOptionMakeupLips:instantiate()
	self:addChild(self.LSMirrorMenuOptionMakeupLips)

	
	self.LSMirrorMenuOptionTattoos = ISButton:new(350, 315, 43, 43, "", self, self.onClickMakeupTattoosOption)
	self.LSMirrorMenuOptionTattoos.internal = "MOMakeupTattoosOff"
	self.LSMirrorMenuOptionTattoos.displayBackground = false
	self.LSMirrorMenuOptionTattoos.borderColor = {r=1, g=1, b=1, a=0};
	if LS_AMcache['tattoo'] then
		self.LSMirrorMenuOptionTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupTattoosOff.png"))
	else
		self.LSMirrorMenuOptionTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_MakeupTattoosDisabled.png"))
		self.LSMirrorMenuOptionTattoos:setTooltip(getText("Tooltip_H_TattooMod"))
		self.LSMirrorMenuOptionTattoos:setEnable(false)
	end
	self.LSMirrorMenuOptionTattoos:initialise()
	self.LSMirrorMenuOptionTattoos:instantiate()
	self:addChild(self.LSMirrorMenuOptionTattoos)


	----CIRCLES
	self.LSMirrorMenuOptionCircleHair = ISButton:new(150, 50, 43, 43, "", self, self.onClickCircleColor)
	self.LSMirrorMenuOptionCircleHair.internal = "None"
	self.LSMirrorMenuOptionCircleHair.displayBackground = false
	self.LSMirrorMenuOptionCircleHair.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionCircleHair:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	self.LSMirrorMenuOptionCircleHair:initialise()
	self.LSMirrorMenuOptionCircleHair:instantiate()
	self.LSMirrorMenuOptionCircleHair:setEnable(false)
	self:addChild(self.LSMirrorMenuOptionCircleHair)

	self.LSMirrorMenuOptionCircleBeard = ISButton:new(200, 50, 43, 43, "", self, self.onClickCircleColor)
	self.LSMirrorMenuOptionCircleBeard.internal = "None"
	self.LSMirrorMenuOptionCircleBeard.displayBackground = false
	self.LSMirrorMenuOptionCircleBeard.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionCircleBeard:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	self.LSMirrorMenuOptionCircleBeard:initialise()
	self.LSMirrorMenuOptionCircleBeard:instantiate()
	self.LSMirrorMenuOptionCircleBeard:setEnable(false)
	self:addChild(self.LSMirrorMenuOptionCircleBeard)

	--Tattoo circles

	self.LSMirrorMenuOptionCircleFaceTattoos = ISButton:new(100, 50, 43, 43, "", self, self.onClickCircleMakeupTattoos)
	self.LSMirrorMenuOptionCircleFaceTattoos.internal = "None"
	self.LSMirrorMenuOptionCircleFaceTattoos.displayBackground = false
	self.LSMirrorMenuOptionCircleFaceTattoos.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionCircleFaceTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	self.LSMirrorMenuOptionCircleFaceTattoos:initialise()
	self.LSMirrorMenuOptionCircleFaceTattoos:instantiate()
	self.LSMirrorMenuOptionCircleFaceTattoos:setEnable(false)
	self:addChild(self.LSMirrorMenuOptionCircleFaceTattoos)

	self.LSMirrorMenuOptionCircleBackTattoos = ISButton:new(250, 50, 43, 43, "", self, self.onClickCircleMakeupTattoos)
	self.LSMirrorMenuOptionCircleBackTattoos.internal = "None"
	self.LSMirrorMenuOptionCircleBackTattoos.displayBackground = false
	self.LSMirrorMenuOptionCircleBackTattoos.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionCircleBackTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	self.LSMirrorMenuOptionCircleBackTattoos:initialise()
	self.LSMirrorMenuOptionCircleBackTattoos:instantiate()
	self.LSMirrorMenuOptionCircleBackTattoos:setEnable(false)
	self:addChild(self.LSMirrorMenuOptionCircleBackTattoos)
	
	--

	for h=1,2 do
		for v=1,4 do
			local idx = ((h-1)*4) + v
			local x = (55+((v-1)*63)+(4*(v-1)))
			local y = (415+((h-1) * 63)) + (3*(h-1))

			local BottomOptionsSqrImg = LSMMdoImageType(x,y,63,63,getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMMSQRH.png"))
			--BottomOptionsSqrImg:setVisible(false)
			BottomOptionsSqrImg:initialise()
			BottomOptionsSqrImg:instantiate()
			self:addChild(BottomOptionsSqrImg)
			bottomMenuSqrList[idx] = BottomOptionsSqrImg
			
			local BOplayermodel = ISCharacterScreenAvatar:new(x+2, y+2, 59, 59)
			BOplayermodel:setVisible(false)
			BOplayermodel:setOutfitName("Foreman", false, false)
			BOplayermodel:setState("idle")
			BOplayermodel:setDirection(IsoDirections.S)
			BOplayermodel:setIsometric(false)
			BOplayermodel:setCharacter(self.character)
			BOplayermodel:setZoom(18)
			BOplayermodel:setYOffset(-0.9)
			self:addChild(BOplayermodel)
			bottomMenuModelList[idx] = BOplayermodel



			local BObutton = ISButton:new(x, y, 63, 63, "", self, self.onClick)
			BObutton.internal = "BB_"
			BObutton.displayBackground = false
			BObutton.borderColor = {r=1, g=1, b=1, a=0};
			--BObutton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MO_DyeOff.png"))
			BObutton:initialise()
			BObutton:instantiate()
			BObutton:setEnable(false)
			self:addChild(BObutton)
			MMbottomMenuButtonList[idx] = BObutton


		end
	end



	self.BOarrowUPButton = ISButton:new(328, 435, 29, 29, "", self, self.onClickArrowUP)
	self.BOarrowUPButton.internal = "UP"
	self.BOarrowUPButton:initialise()
	self.BOarrowUPButton:instantiate()
	self.BOarrowUPButton:setEnable(false)
	self.BOarrowUPButton.displayBackground = false
	self.BOarrowUPButton.borderColor = {r=1, g=1, b=1, a=0};
	self.BOarrowUPButton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_ArrowUpBT.png"))
	self:addChild(self.BOarrowUPButton)

	self.BOarrowDownButton = ISButton:new(328, 500, 29, 29, "", self, self.onClickArrowDOWN)
	self.BOarrowDownButton.internal = "DOWN"
	self.BOarrowDownButton:initialise()
	self.BOarrowDownButton:setEnable(false)
	self.BOarrowDownButton:instantiate()
	self.BOarrowDownButton.displayBackground = false
	self.BOarrowDownButton.borderColor = {r=1, g=1, b=1, a=0};
	self.BOarrowDownButton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_ArrowDownBT.png"))
	self:addChild(self.BOarrowDownButton)

	self.resetAllButton = ISButton:new(40, 550, 27, 27, "", self, self.onResetChangeAll)
	self.resetAllButton.internal = "resetNone"
	self.resetAllButton:initialise()
	self.resetAllButton:instantiate()
	self.resetAllButton.displayBackground = false
	self.resetAllButton.borderColor = {r=1, g=1, b=1, a=0};
	self.resetAllButton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_ResetAllBT.png"))
	self.resetAllButton:setTooltip(getText("Tooltip_H_ResetAll"))
	self.resetAllButton:setEnable(false)
	self:addChild(self.resetAllButton)

	self.resetSpecificButton = ISButton:new(75, 558, 20, 20, "", self, self.onResetChange)
	self.resetSpecificButton.internal = "resetNone"
	self.resetSpecificButton:initialise()
	self.resetSpecificButton:instantiate()
	self.resetSpecificButton.displayBackground = false
	self.resetSpecificButton.borderColor = {r=1, g=1, b=1, a=0};
	self.resetSpecificButton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_ResetSpecBT.png"))
	self.resetSpecificButton:setTooltip(getText("Tooltip_H_ResetSpecific"))
	self.resetSpecificButton:setEnable(false)
	self:addChild(self.resetSpecificButton)

	self.removeMakeupButton = ISButton:new(100, 558, 20, 20, "", self, self.onRemoveMakeup)
	self.removeMakeupButton.internal = "removeNone"
	self.removeMakeupButton:initialise()
	self.removeMakeupButton:instantiate()
	self.removeMakeupButton.displayBackground = false
	self.removeMakeupButton.borderColor = {r=1, g=1, b=1, a=0};
	self.removeMakeupButton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_RemoveMakeupBT.png"))
	self.removeMakeupButton:setTooltip(getText("Tooltip_H_RemoveMakeupCat"))
	self.removeMakeupButton:setEnable(false)
	self:addChild(self.removeMakeupButton)

    self.playermodel = ISCharacterScreenAvatar:new(38, 105, 294, 294)
	self.playermodel:setVisible(true)
	self:addChild(self.playermodel)
	self.playermodel:setOutfitName("Foreman", false, false)
	self.playermodel:setState("idle")
	self.playermodel:setDirection(IsoDirections.S)
	self.playermodel:setIsometric(false)
    self.playermodel:setCharacter(self.character)
	self.playermodel:setZoom(18)
	self.playermodel:setYOffset(-0.9)
	--self.playermodel:setAnimSetName("Shave")
	
    ---------ITEMS ICONS
	--Items.Makeup, Items.MakeupEye, Items.MakeupLipstick, Items.Scissors, Items.Razor, Items.Hairgel
	local iconTexture, iconTooltip = MMgetIconItemTextureTooltip(self.itemsList.Scissors, getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_ScissorsOn.png"), getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_ScissorsOff.png"), getText("Tooltip_H_ScissorsOn"), getText("Tooltip_H_ScissorsOff"))
	self.iconScissors = LSMMdoImageType(40,110,20,20,iconTexture)
	self.iconScissors:setMouseOverText(iconTooltip)
	self.iconScissors:initialise()
	self:addChild(self.iconScissors)

	iconTexture, iconTooltip = MMgetIconItemTextureTooltip(self.itemsList.Razor, getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_RazorOn.png"), getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_RazorOff.png"), getText("Tooltip_H_RazorOn"), getText("Tooltip_H_RazorOff"))
	self.iconRazor = LSMMdoImageType(65,110,20,20,iconTexture)
	self.iconRazor:setMouseOverText(iconTooltip)
	self.iconRazor:initialise()
	self:addChild(self.iconRazor)

	iconTexture, iconTooltip = MMgetIconItemTextureTooltip(self.itemsList.Hairgel, getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_HairgelOn.png"), getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_HairgelOff.png"), getText("Tooltip_H_HairgelOn"), getText("Tooltip_H_HairgelOff"))
	self.iconHairgel = LSMMdoImageType(90,110,20,20,iconTexture)
	self.iconHairgel:setMouseOverText(iconTooltip)
	self.iconHairgel:initialise()
	self:addChild(self.iconHairgel)

	iconTexture, iconTooltip = MMgetIconItemTextureTooltip(self.itemsList.Makeup, getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupOn.png"), getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupOff.png"), getText("Tooltip_H_MakeupOn"), getText("Tooltip_H_MakeupOff"))
	self.iconMakeup = LSMMdoImageType(115,110,20,20,iconTexture)
	self.iconMakeup:setMouseOverText(iconTooltip)
	self.iconMakeup:initialise()
	self:addChild(self.iconMakeup)

	iconTexture, iconTooltip = MMgetIconItemTextureTooltip(self.itemsList.MakeupEye, getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupEyeOn.png"), getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupEyeOff.png"), getText("Tooltip_H_MakeupEyeOn"), getText("Tooltip_H_MakeupEyeOff"))
	self.iconMakeupEye = LSMMdoImageType(140,110,20,20,iconTexture)
	self.iconMakeupEye:setMouseOverText(iconTooltip)
	self.iconMakeupEye:initialise()
	self:addChild(self.iconMakeupEye)

	iconTexture, iconTooltip = MMgetIconItemTextureTooltip(self.itemsList.MakeupLipstick, getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupLipstickOn.png"), getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupLipstickOff.png"), getText("Tooltip_H_MakeupLipstickOn"), getText("Tooltip_H_MakeupLipstickOff"))
	self.iconMakeupLipstick = LSMMdoImageType(165,110,20,20,iconTexture)
	self.iconMakeupLipstick:setMouseOverText(iconTooltip)
	self.iconMakeupLipstick:initialise()
	self:addChild(self.iconMakeupLipstick)

	--makeup original
	self.mO.FF = MMgetMakeupBodyLocationItem(self.character, "FullFace")
	self.mO.E = MMgetMakeupBodyLocationItem(self.character, "Eyes")
	self.mO.ES = MMgetMakeupBodyLocationItem(self.character, "EyesShadow")
	self.mO.L = MMgetMakeupBodyLocationItem(self.character, "Lips")
	---------
	--item icon tattoo

	if LS_AMcache['tattoo'] then
		self.mO.FT = MMgetMakeupBodyLocationItem(self.character, "Face_Tattoo")
		self.mO.UBT = MMgetMakeupBodyLocationItem(self.character, "UpperBody_Tattoo")
		self.mO.LBT = MMgetMakeupBodyLocationItem(self.character, "LowerBody_Tattoo")
		self.mO.BT = MMgetMakeupBodyLocationItem(self.character, "Back_Tattoo")
		self.mO.LAT = MMgetMakeupBodyLocationItem(self.character, "LeftArm_Tattoo")
		self.mO.RAT = MMgetMakeupBodyLocationItem(self.character, "RightArm_Tattoo")
		self.mO.LLT = MMgetMakeupBodyLocationItem(self.character, "LeftLeg_Tattoo")
		self.mO.RLT = MMgetMakeupBodyLocationItem(self.character, "RightLeg_Tattoo")

		iconTexture, iconTooltip = MMgetIconItemTextureTooltip(self.itemsList.MakeupTattooNeedle, getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupTattooOn.png"), getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_Icon_MakeupTattooOff.png"), getText("Tooltip_H_MakeupTattooOn"), getText("Tooltip_H_MakeupTattooOff"))
		self.iconMakeupTattoo = LSMMdoImageType(190,110,20,20,iconTexture)
		self.iconMakeupTattoo:setMouseOverText(iconTooltip)
		self.iconMakeupTattoo:initialise()
		self:addChild(self.iconMakeupTattoo)
	end
	----
	--tattoo small circles
	
	self.LSMirrorMenuOptionCircleLeftLegTattoos = ISButton:new(250, 108, 33, 33, "", self, self.onClickCircleMakeupTattoosSub)
	self.LSMirrorMenuOptionCircleLeftLegTattoos.internal = "None"
	self.LSMirrorMenuOptionCircleLeftLegTattoos.displayBackground = false
	self.LSMirrorMenuOptionCircleLeftLegTattoos.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionCircleLeftLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	self.LSMirrorMenuOptionCircleLeftLegTattoos:initialise()
	self.LSMirrorMenuOptionCircleLeftLegTattoos:instantiate()
	self.LSMirrorMenuOptionCircleLeftLegTattoos:setEnable(false)
	self:addChild(self.LSMirrorMenuOptionCircleLeftLegTattoos)

	self.LSMirrorMenuOptionCircleRightLegTattoos = ISButton:new(288, 108, 33, 33, "", self, self.onClickCircleMakeupTattoosSub)
	self.LSMirrorMenuOptionCircleRightLegTattoos.internal = "None"
	self.LSMirrorMenuOptionCircleRightLegTattoos.displayBackground = false
	self.LSMirrorMenuOptionCircleRightLegTattoos.borderColor = {r=1, g=1, b=1, a=0};
	self.LSMirrorMenuOptionCircleRightLegTattoos:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_MOH.png"))
	self.LSMirrorMenuOptionCircleRightLegTattoos:initialise()
	self.LSMirrorMenuOptionCircleRightLegTattoos:instantiate()
	self.LSMirrorMenuOptionCircleRightLegTattoos:setEnable(false)
	self:addChild(self.LSMirrorMenuOptionCircleRightLegTattoos)


	--

	self.confirmChangesButton = ISButton:new(335, 555, 29, 29, "", self, self.onConfirmChanges)
	self.confirmChangesButton.internal = "CloseSave"
	self.confirmChangesButton:initialise()
	self.confirmChangesButton:instantiate()
	self.confirmChangesButton.displayBackground = false
	self.confirmChangesButton.borderColor = {r=1, g=1, b=1, a=0};
	self.confirmChangesButton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_ConfirmBT.png"))
	self.confirmChangesButton:setTooltip(getText("Tooltip_H_CloseSave"))
	self:addChild(self.confirmChangesButton)
	
    self.XButton = ISButton:new(17, 47, 29, 29, "", self, LSMirrorMenu.onClick);
    self.XButton.internal = "Close";
    self.XButton:initialise();
    self.XButton:instantiate();
	self.XButton.displayBackground = false
	self.XButton.borderColor = {r=1, g=1, b=1, a=0};
	self.XButton:setImage(getTexture("media/textures/LSMM/"..self.menuSkin.."/LSMM_CloseBT.png"))
	self.XButton:setTooltip(getText("Tooltip_H_CloseNoSave"))
    self:addChild(self.XButton);

	MMmenuList = {{option=self.LSMirrorMenuOptionDye,internal="MODyeOn",tex="DyeOff",off="MODyeOff"}, {option=self.LSMirrorMenuOptionHairstyle,internal="MOHairstyleOn",tex="HairstyleOff",off="MOHairstyleOff"},
	{option=self.LSMirrorMenuOptionMakeupFull,internal="MOMakeupFullOn",tex="MakeupFullOff",off="MOMakeupFullOff"}, {option=self.LSMirrorMenuOptionMakeupEyes,internal="MOMakeupEyesOn",tex="MakeupEyesOff",off="MOMakeupEyesOff"},
	{option=self.LSMirrorMenuOptionMakeupLips,internal="MOMakeupLipsOn",tex="MakeupLipsOff",off="MOMakeupLipsOff"}, {option=self.LSMirrorMenuOptionTattoos,internal="MOMakeupTattoosOn",tex="MakeupTattoosOff",off="MOMakeupTattoosOff"}}

	MMcircleList = {self.LSMirrorMenuOptionCircleHair, self.LSMirrorMenuOptionCircleBeard, self.LSMirrorMenuOptionCircleBackTattoos, self.LSMirrorMenuOptionCircleFaceTattoos,
	self.LSMirrorMenuOptionCircleLeftLegTattoos, self.LSMirrorMenuOptionCircleRightLegTattoos}

	MMcircleSubList = {self.LSMirrorMenuOptionCircleLeftLegTattoos, self.LSMirrorMenuOptionCircleRightLegTattoos}

	local menuSkinList = require("Properties/LSMMSkins")
	if menuSkinList and (#menuSkinList > 1) then
		local numb, numbFinal = 0, false
		self.menuSkinCombo = ISComboBox:new(370,400, 90, 15, self, self.onMenuSkinComboSelected)
		self.menuSkinCombo.backgroundColor = {r=0, g=0, b=0, a=0};
		self.menuSkinCombo.backgroundColorMouseOver = {r=0.3, g=0.3, b=0.3, a=0.3};
		self.menuSkinCombo:initialise()
		self:addChild(self.menuSkinCombo)
		for k, v in pairs(menuSkinList) do
			self.menuSkinCombo:addOptionWithData(getText(v.name), v.name)
			if not numbFinal then numb = numb+1; end
			if specificPlayer and specificPlayer:getModData().LSMirrorMenuOverlayPanelSkin and tostring(specificPlayer:getModData().LSMirrorMenuOverlayPanelSkin) and
			(v.name == specificPlayer:getModData().LSMirrorMenuOverlayPanelSkin) and not numbFinal then
				numbFinal = numb
			end
		end
		if not numbFinal then numbFinal = 1; end
		self.menuSkinCombo.selected = numbFinal
	end

end

function LSMirrorMenu:render()
    ISPanelJoypad.render(self);


end

function LSMirrorMenu:close()

	if self.resetHairColor then self.character:getHumanVisual():setHairColor(self.resetHairColor); end
	if self.resetBeardColor then self.character:getHumanVisual():setBeardColor(self.resetBeardColor); end
	if self.resetHairChange then self.character:getHumanVisual():setHairModel(self.resetHairChange); end
	if self.resetBeardChange then self.character:getHumanVisual():setBeardModel(self.resetBeardChange); end
	
	local bodyLocationItem
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "FullFace")
	if (self.resetMakeupFull ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupFull and (self.resetMakeupFull ~= 0) then self.character:setWornItem(self.resetMakeupFull:getBodyLocation(), self.resetMakeupFull); elseif (not bodyLocationItem) and self.mO and self.mO.FF then self.character:setWornItem(self.mO.FF:getBodyLocation(), self.mO.FF); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Eyes")
	if (self.resetMakeupEye ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupEye and (self.resetMakeupEye ~= 0) then self.character:setWornItem(self.resetMakeupEye:getBodyLocation(), self.resetMakeupEye); elseif (not bodyLocationItem) and self.mO and self.mO.E then self.character:setWornItem(self.mO.E:getBodyLocation(), self.mO.E); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "EyesShadow")
	if (self.resetMakeupEyeShadow ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupEyeShadow and (self.resetMakeupEyeShadow ~= 0) then self.character:setWornItem(self.resetMakeupEyeShadow:getBodyLocation(), self.resetMakeupEyeShadow); elseif (not bodyLocationItem) and self.mO and self.mO.ES then self.character:setWornItem(self.mO.ES:getBodyLocation(), self.mO.ES); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Lips")
	if (self.resetMakeupLipstick ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupLipstick and (self.resetMakeupLipstick ~= 0) then self.character:setWornItem(self.resetMakeupLipstick:getBodyLocation(), self.resetMakeupLipstick); elseif (not bodyLocationItem) and self.mO and self.mO.L then self.character:setWornItem(self.mO.L:getBodyLocation(), self.mO.L); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Face_Tattoo")
	if (self.resetMakeupTattooFace ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooFace and (self.resetMakeupTattooFace ~= 0) then self.character:setWornItem(self.resetMakeupTattooFace:getBodyLocation(), self.resetMakeupTattooFace); elseif (not bodyLocationItem) and self.mO and self.mO.FT then self.character:setWornItem(self.mO.FT:getBodyLocation(), self.mO.FT); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "UpperBody_Tattoo")
	if (self.resetMakeupTattooUB ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooUB and (self.resetMakeupTattooUB ~= 0) then self.character:setWornItem(self.resetMakeupTattooUB:getBodyLocation(), self.resetMakeupTattooUB); elseif (not bodyLocationItem) and self.mO and self.mO.UBT then self.character:setWornItem(self.mO.UBT:getBodyLocation(), self.mO.UBT); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LowerBody_Tattoo")
	if (self.resetMakeupTattooLB ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLB and (self.resetMakeupTattooLB ~= 0) then self.character:setWornItem(self.resetMakeupTattooLB:getBodyLocation(), self.resetMakeupTattooLB); elseif (not bodyLocationItem) and self.mO and self.mO.LBT then self.character:setWornItem(self.mO.LBT:getBodyLocation(), self.mO.LBT); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "Back_Tattoo")
	if (self.resetMakeupTattooBack ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooBack and (self.resetMakeupTattooBack ~= 0) then self.character:setWornItem(self.resetMakeupTattooBack:getBodyLocation(), self.resetMakeupTattooBack); elseif (not bodyLocationItem) and self.mO and self.mO.BT then self.character:setWornItem(self.mO.BT:getBodyLocation(), self.mO.BT); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftArm_Tattoo")
	if (self.resetMakeupTattooLA ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLA and (self.resetMakeupTattooLA ~= 0) then self.character:setWornItem(self.resetMakeupTattooLA:getBodyLocation(), self.resetMakeupTattooLA); elseif (not bodyLocationItem) and self.mO and self.mO.LAT then self.character:setWornItem(self.mO.LAT:getBodyLocation(), self.mO.LAT); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightArm_Tattoo")
	if (self.resetMakeupTattooRA ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooRA and (self.resetMakeupTattooRA ~= 0) then self.character:setWornItem(self.resetMakeupTattooRA:getBodyLocation(), self.resetMakeupTattooRA); elseif (not bodyLocationItem) and self.mO and self.mO.RAT then self.character:setWornItem(self.mO.RAT:getBodyLocation(), self.mO.RAT); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "LeftLeg_Tattoo")
	if (self.resetMakeupTattooLL ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooLL and (self.resetMakeupTattooLL ~= 0) then self.character:setWornItem(self.resetMakeupTattooLL:getBodyLocation(), self.resetMakeupTattooLL); elseif (not bodyLocationItem) and self.mO and self.mO.LLT then self.character:setWornItem(self.mO.LLT:getBodyLocation(), self.mO.LLT); end;
	bodyLocationItem = MMgetMakeupBodyLocationItem(self.character, "RightLeg_Tattoo")
	if (self.resetMakeupTattooRL ~= 0) and bodyLocationItem then self.character:removeWornItem(bodyLocationItem); end; if self.resetMakeupTattooRL and (self.resetMakeupTattooRL ~= 0) then self.character:setWornItem(self.resetMakeupTattooRL:getBodyLocation(), self.resetMakeupTattooRL); elseif (not bodyLocationItem) and self.mO and self.mO.RLT then self.character:setWornItem(self.mO.RLT:getBodyLocation(), self.mO.RLT); end;

	--if self.resetBeardColor or self.resetHairColor or self.resetHairChange or self.resetBeardChange or self.previewMakeupFull then
		self.character:resetModel();
		sendVisual(self.character);
	--end

	local specificPlayer = getSpecificPlayer(0)
	if specificPlayer:getModData().LSMirrorMenuOverlayPanel ~= "changeSkin" then
		specificPlayer:getModData().LSMirrorMenuOverlayPanel = false
	end
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSMirrorMenu:destroy()

	local specificPlayer = getSpecificPlayer(0)
	specificPlayer:getModData().LSMirrorMenuOverlayPanel = false
	self:setVisible(false);
	self:removeFromUIManager();
end

function LSMirrorMenu:new(X, Y, Width, Height, Player, Items, ItemsDye, Hairstyles, Beardstyles, MakeupTypes)
	local o = ISPanelJoypad:new(X, Y, Width, Height)
	setmetatable(o, self)
	self.__index = self
	local playerObj = Player and getSpecificPlayer(Player) or nil
    o.character = playerObj;
	o.backgroundColor = {r=0.1, g=0.1, b=0.1, a=0.98}
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
	o.itemsList = Items
	o.itemsDyeList = ItemsDye
	o.hairList = Hairstyles
	o.beardList = Beardstyles
	o.makeupList = MakeupTypes
	o:noBackground()
	o.bottomMenuSelected = false
	o.currentPage = 1
	o.pagesTotal = 1
	o.anchorLeft = true;
	o.anchorRight = true;
	o.anchorTop = true;
	o.anchorBottom = true;
	o.panelH = Height
	o.panelW = Width
	o.playermodel = false
	o.BOarrowDownButton = false
	o.BOarrowUPButton = false
	o.resetHairColor = false
	o.resetBeardColor = false
	o.resetHairChange = false
	o.resetBeardChange = false
	o.hairDyeItem = false
	o.beardDyeItem = false
	o.resetMakeupFull = 0
	o.resetMakeupEyeShadow = 0
	o.resetMakeupEye = 0
	o.resetMakeupLipstick = 0
	o.resetMakeupTattooFace = 0
	o.resetMakeupTattooBack = 0
	o.resetMakeupTattooUB = 0
	o.resetMakeupTattooLB = 0
	o.resetMakeupTattooLA = 0
	o.resetMakeupTattooRA = 0
	o.resetMakeupTattooLL = 0
	o.resetMakeupTattooRL = 0
	o.acidBrush = false
	o.menuSkin = "LSSims"
	o.mO = {}
	return o
end





