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

LSIWAddItems = ISBaseTimedAction:derive("LSIWAddItems");

function LSIWAddItems:isValid()
	return true
end

function LSIWAddItems:waitToStart()
	self.action:setUseProgressBar(true)
	self.character:faceThisObject(self.obj);
	return self.character:shouldBeTurning();
end

function LSIWAddItems:update()
	if self.character:isSitOnGround() then self:forceStop(); end

end

function LSIWAddItems:start()
	self:setOverrideHandModels(nil, nil)
	self:setActionAnim("Loot")
	self.character:SetVariable("LootPosition", "Mid")
	self.character:getEmitter():playSound("PutItemInBag")
end

function LSIWAddItems:stop()
    ISBaseTimedAction.stop(self);		
end

function LSIWAddItems:perform()
	if not self.emptySprite and self.newID and LSSync.isNotServer() then
		local charData = self.character:getModData()
		charData['invData'] = charData['invData'] or {}
		charData['invData']['lsWkID'] = self.newID
		LSSync.updateClientData(self.character, self.character:getModData())
		
		local isReady = (self.workParams[2] == "Production" and "c") or "a"
		local noteTex = "media/ui/IW_icon.png"
		local noteText = "<RGB:0.9,0.9,0.9><CENTRE>"..getText("Tooltip_InvWorkbench_Title_"..self.workParams[2]).." <LINE><TEXT>"..getText("Tooltip_InvWorkbench_"..self.workParams[2].."_a1")..
		" <LINE><CENTRE><RGB:0.9,0.9,0.9>"..getText("Tooltip_InvWorkbench_Ready_"..isReady).." <LINE><RGB:0.7,0.7,0.7>"..getText("Tooltip_InvWorkbench_Ready_b")
		LSNoteMng.addToQueue(getCore():getScreenWidth()-200,(getCore():getScreenHeight()/5)-50,100,50, {self.character, noteText, false, noteTex, 5, false, false, false, {6,10,30}})
	end
	ISBaseTimedAction.perform(self);
end

local function updateMatList(character, inventory, matList)
	if not matList then return false, false, false; end
	local consumeList, newList = {}, {}
	local rdmList = LSUtil.getRandomKeys(matList, LSUtil.rdm_inst:random(2,4), nil, {["upgradeElectric"]=true,["upgradeElectricRare"]=true,["upgradeMechanical"]=true,["upgradeMechanicalRare"]=true,["upgradePlumbing"]=true,["upgradePlumbingRare"]=true,["upgradeWood"]=true,["upgradeWoodRare"]=true})
	local hasMat
	for k, v in pairs(matList) do
		if rdmList[k] then
			local rdmCost = LSUtil.rdm_inst:random(math.max(1, math.min(20,v)))
			rdmList[k] = rdmCost
		end
		local itemCount = inventory:getItemCount(k, true)
		if itemCount > 0 and LSUtil.getItemDrainable(character, k, 1) then itemCount = LSUtil.getTotalItemDrainableCount(character, k); end
		local remainingReqItems = v
		if itemCount > 0 and v > 0 then
			hasMat = true
			remainingReqItems = math.floor(v-itemCount)
			consumeList[k] = math.min(itemCount, v)
		end
		if remainingReqItems > 0 then newList[k] = remainingReqItems; end
	end
	if not hasMat then return false, matList, rdmList; end
	return consumeList, newList, rdmList
end

function LSIWAddItems:complete()
	--print("LSIWAddItems, running complete")
	local consumeList, newList, rdmList = updateMatList(self.character, self.character:getInventory(), self.matList)

	if LSUtil.isValidObj(self.obj, "Inv Workbench") and LSUtil.isObjOnSqr(self.obj) then
		--print("LSIWAddItems, valid obj and is on sqr")
		if consumeList then LSUtil.consumeItemsOnChar(self.character, consumeList); end
		if not self.emptySprite and self.newID then -- work phase 0 and not emptySprite
			--print("LSIWAddItems, not emptySprite and has newID")
			local charDescriptor = self.character:getDescriptor()
			self.data['lsWkID'] = self.newID
			self.data['author'] = charDescriptor:getForename().." "..charDescriptor:getSurname()
			self.data['workPhase'] = 1
			self.data['workType'] = self.workParams[2]
			self.data['invName'] = self.workParams[3]
			self.data['resultType'] = self.workParams[4]
			self.data['result'] = self.workParams[5]
			self.data['level'] = self.workParams[6]
			--local duration = InvWorkbenchMenu.getProductionDuration(charData['invData'], HiddenSkills.getLevel(self.character, "Inventing"), self.workParams[2])
			self.data['duration'] = false
			self.data['progress'] = false
			self.data['events'] = {}
		end
		self.data['workCost'] = newList
		if not self.data['costFail'] or not self.matList then self.data['costFail'] = rdmList; end
		--if self.data['lsWkID'] then print("has lsWkID data"); end
		LSSync.rewriteData(self.obj, self.data)
		local transmitSprite
		if self.overlay then self.obj:setOverlaySprite(self.overlay,true); transmitSprite = true; end
		if self.newSprite then self.obj:setSprite(self.newSprite); transmitSprite = true; end
		if transmitSprite then self.obj:transmitUpdatedSpriteToClients(); end
		self.obj:transmitModData()
		--if not self.data['lsWkID'] then print("lost lsWkID data"); end
	end
	
	return true
end

function LSIWAddItems:getDuration()
	if self.character:isTimedActionInstant() then
		return 1
	end
	return 100
end

local function getNewSpriteAndOverlay(key, group, phase)
	local overlayE, overlayS = "_8","_9"
	if group ~= "Production" and phase < 2 then overlayE, overlayS = "_34","_35"; end
	local t = {
		LS_Inventions_4 = {"LS_Inventions_10","LS_Inventions"..overlayE},
		LS_Inventions_5 = {"LS_Inventions_11","LS_Inventions"..overlayS},
	}
	return t[key][1], t[key][2]
end

-- adds items to workbench or prepares it for inventing and research
function LSIWAddItems:new(character, obj, args) -- newID, data, matList, spriteName, emptySprite, workParams
	local o = {}
	setmetatable(o, self)
	self.__index = self
	o.character = character
	o.obj = obj
	o.args = args
	o.newID = o.args[1]
	o.data = o.args[2]
	o.matList = o.args[3]
	o.spriteName = o.args[4]
	o.emptySprite = o.args[5]
	o.workParams = o.args[6]
	if not o.emptySprite then o.newSprite, o.overlay = getNewSpriteAndOverlay(o.spriteName, o.workParams[2], o.workParams[1]); end
	o.ignoreDynamicTime = true
    o.stopOnWalk        = true
    o.stopOnRun         = true
	o.stopOnAim         = true
	o.maxTime = o:getDuration()
	o.isInv = LSUtil.StringStartWith(o.workParams[4],"inv")
	return o;
end
