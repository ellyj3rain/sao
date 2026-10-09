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

local function ambtIsValid(data, name)
	return data and data[name]
end

local function ambtIsActive(data, name)
	return data[name].isActive
end

local function ambtIsCompleted(data, name)
	return data[name].completed
end

local function isRepairRecipe(data)
	local recipe = data and data:getRecipe()
	local cat = recipe and recipe:getCategory()
	return cat and cat == "Repair"
end

local function isRepairItem(item)
	return item and instanceof(item, "InventoryItem") and item.getHaveBeenRepaired and item:getHaveBeenRepaired() ~= nil
end

local function getRepairItem(self)
	local items = self.items
	if not items then return false; end
	for i = 0, items:size() - 1 do
		local item = items:get(i)
		if isRepairItem(item) then
			return item
		end
	end
	return false
end

local ogHC_perform = ISHandcraftAction.perform
local ogHC_performRecipe = ISHandcraftAction.performRecipe

--[[


function ISHandcraftAction:complete()
	print("ISHandcraftAction:complete() called")
	ogHC_complete(self)
end
]]--
function ISHandcraftAction:perform()
	if isRepairRecipe(self.logic and self.logic:getRecipeData()) then
		local playerData = self.character and self.character:getModData()
		local data = playerData and playerData.Ambitions
		if ambtIsValid(data, "LSJuryRigger") and not ambtIsCompleted(data, "LSJuryRigger") and ambtIsActive(data, "LSJuryRigger") then
			data['LSJuryRigger'].goal1progress = (data['LSJuryRigger'].goal1progress and math.floor(data['LSJuryRigger'].goal1progress+1)) or 1
			--print("ISHandcraftAction:perform() LSJuryRigger goal1progress is "..tostring(data['LSJuryRigger'].goal1progress))
		end
	end
	ogHC_perform(self)
end

function ISHandcraftAction:performRecipe()
	--print("ISHandcraftAction:performRecipe() called")
	ogHC_performRecipe(self)
	--print("ISHandcraftAction:performRecipe() start of custom code")
	local playerData = self.character and self.character:getModData()
	local data = playerData and playerData.Ambitions
	if isRepairRecipe(self.logic and self.logic:getRecipeData()) and ambtIsValid(data, "LSJuryRigger") then
		--print("ISHandcraftAction:performRecipe() is valid JR")
		if ambtIsCompleted(data, "LSJuryRigger") then
			--print("ISHandcraftAction:performRecipe() JR is completed")
			local repairItem = getRepairItem(self)
			if repairItem then
				local JRrepair = repairItem:getModData().JRrepair
				local repairNum = repairItem:getHaveBeenRepaired()
				--if repairNum then print("ISHandcraftAction:performRecipe() repairNum is "..repairNum); end
				if repairNum and (repairNum < 2) and (not JRrepair) then
					repairItem:getModData().JRrepair = 0
					repairItem:setHaveBeenRepaired(0)
					--print("ISHandcraftAction:performRecipe() first repair")
					if isServer() then repairItem:syncItemFields(); end
				elseif ambtIsActive(data, "LSJuryRigger") then
					if not repairItem:getModData().JRrepair then repairItem:getModData().JRrepair = 0; end
					--if not self.character:getModData().JRrepair then self.character:getModData().JRrepair = 0; end
					repairItem:getModData().JRrepair = math.floor(repairItem:getModData().JRrepair+1)
					if math.floor((JRrepair+1))%2 == 0 then -- true only if it's an even number, else is false
						if not repairNum then repairNum = 1; end
						local repairTotal = math.floor(repairNum-1)
						--print("ISHandcraftAction:performRecipe() repair total is "..repairTotal)
						--print("ISHandcraftAction:performRecipe() JRrepair total is "..repairItem:getModData().JRrepair)
						repairItem:setHaveBeenRepaired(repairTotal)
					end
					if isServer() then repairItem:syncItemFields(); end
				end
			end
		--elseif ambtIsActive(data, "LSJuryRigger") then
		--	print("ISHandcraftAction:performRecipe() JR is active")
		--	data['LSJuryRigger'].goal1progress = (data['LSJuryRigger'].goal1progress and math.floor(data['LSJuryRigger'].goal1progress+1)) or 0
		--	print("ISHandcraftAction:perform() LSJuryRigger goal1progress is "..tostring(data['LSJuryRigger'].goal1progress))
		end
	end
end

local ogFV_perform = ISFixVehiclePartAction.perform
local ogFV_complete = ISFixVehiclePartAction.complete

function ISFixVehiclePartAction:perform()
	--print("ISFixVehiclePartAction:complete() perform")
	local playerData = self.character and self.character:getModData()
	local data = playerData and playerData.Ambitions
	if ambtIsValid(data, "LSJuryRigger") and ambtIsActive(data, "LSJuryRigger") and not ambtIsCompleted(data, "LSJuryRigger") then
		data['LSJuryRigger'].goal1progress = (data['LSJuryRigger'].goal1progress and math.floor(data['LSJuryRigger'].goal1progress+1)) or 1
		--print("ISFixVehiclePartAction:perform() LSJuryRigger goal1progress is "..tostring(data['LSJuryRigger'].goal1progress))
	end
	ogFV_perform(self)
end

function ISFixVehiclePartAction:complete()
	--print("ISFixVehiclePartAction:complete() called")
	ogFV_complete(self)
	--print("ISFixVehiclePartAction:complete() start of custom code")
	local playerData = self.character and self.character:getModData()
	local data = playerData and playerData.Ambitions
	if ambtIsValid(data, "LSJuryRigger") and ambtIsCompleted(data, "LSJuryRigger") then
		local JRrepair = self.item:getModData().JRrepair
		--if self.vehiclePart then JRrepair = self.character:getModData().JRrepair; end
		local repairNum = self.item:getHaveBeenRepaired()
		--if repairNum then print("ISFixVehiclePartAction:complete() repairNum is "..repairNum); end
		if repairNum and (repairNum < 2) and (not JRrepair) then
			self.item:getModData().JRrepair = 0
			--if self.vehiclePart then playerData.JRrepair = 0; end
			self.item:setHaveBeenRepaired(0)
			--print("ISFixVehiclePartAction:complete() first repair")
			if isServer() then self.item:syncItemFields(); end
		elseif ambtIsActive(data, "LSJuryRigger") then
			if not self.item:getModData().JRrepair then self.item:getModData().JRrepair = 0; end
			--if not self.character:getModData().JRrepair then self.character:getModData().JRrepair = 0; end
			self.item:getModData().JRrepair = math.floor(self.item:getModData().JRrepair+1)
			--if self.vehiclePart then self.character:getModData().JRrepair = math.floor(self.character:getModData().JRrepair+1); end
			if math.floor((JRrepair+1))%2 == 0 then -- true only if it's an even number, else is false
				if not repairNum then repairNum = 1; end
				local repairTotal = math.floor(repairNum-1)
				--print("ISFixVehiclePartAction:complete() repair total is "..repairTotal)
				--print("ISFixVehiclePartAction:complete() JRrepair total is "..self.item:getModData().JRrepair)
				self.item:setHaveBeenRepaired(repairTotal)
			end
			if isServer() then self.item:syncItemFields(); end
		end		
		self.vehiclePart:getVehicle():updatePartStats()
		self.vehiclePart:getVehicle():updateBulletStats()
		self.vehiclePart:getVehicle():transmitPartItem(self.vehiclePart)
	end
	return true
end
