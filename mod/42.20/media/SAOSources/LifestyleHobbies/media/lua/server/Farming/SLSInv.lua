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

if isClient() then return; end

require "Map/SGlobalObjectSystem"
require "Farming/SFarmingSystem"

--local harvestVars = {'minVeg','maxVeg','minVegAutorized','maxVegAutorized'}

local function getExtraItems(luaObject)
	local extraItems
	if luaObject and luaObject.typeOfSeed and luaObject.typeOfSeed == "LSScrapBush" then
		local props = farming_vegetableconf.props[luaObject.typeOfSeed]
		if props.extraRandom and props.maxVeg and props.maxVeg > 0 then
			extraItems = {}
			for n=1,#props.extraRandom do
				local maxNum = math.floor(props.maxVeg/2)
				local randomNum = LSUtil.rdm_inst:random(0,maxNum)
				if randomNum > 0 then
					local produce = props.extraRandom[n]
					table.insert(extraItems, produce)
					table.insert(extraItems, randomNum)
				end
			end
		end
	end	
	return extraItems
end

local function sendHarvestToContainers(player, itemCont, produceName, num)
	if not num or num <= 0 then return; end
	local plant = instanceItem(produceName)
	if not plant then return; end
	local weight = (plant.getWeight and plant:getWeight()) or 0
	local toCont = 0
	local weightTotal = 0
	for n=1, num do
		if not itemCont:hasRoomFor(player, weightTotal+weight) then break; end
		toCont = toCont+1
		weightTotal = weightTotal+weight
	end
	local toPlayer = math.max(0, num-toCont)
	if toCont > 0 then
		local items = itemCont:AddItems(produceName, toCont)
		sendAddItemsToContainer(itemCont, items)
	end
	if toPlayer > 0 then
		local playerInv = player:getInventory()
		local items = playerInv:AddItems(produceName, toPlayer)
		sendAddItemsToContainer(playerInv, items)
	end
end

local function harvesterFarming(self, luaObject, player, data, itemCont)
	local skill = player:getPerkLevel(Perks.Farming)
	--local props = LSUtil.deepCopy(farming_vegetableconf.props[luaObject.typeOfSeed])
	local props = farming_vegetableconf.props[luaObject.typeOfSeed]
	local numberOfVeg = getVegetablesNumber(props.minVeg, props.maxVeg, props.minVegAutorized, props.maxVegAutorized, luaObject, skill)
				
	if numberOfVeg > 0 and props.isFlower then
		player:getStats():remove(CharacterStat.UNHAPPINESS, numberOfVeg/2)
		player:getStats():remove(CharacterStat.BOREDOM, numberOfVeg/2)
		player:getStats():remove(CharacterStat.STRESS, numberOfVeg/2)
	end
				
	local vegNum = tonumber(numberOfVeg)

	LSUtil.debugDiagnostics("/server/Farming/SLSInv", "SFarmingSystem:harvest",{
	['data.replant']=data.replant,
	['data.booster']=data.booster,
	['props.vegetableName']=props.vegetableName,
	['props.isFlower']=props.isFlower,
	['props.produceExtra']=props.produceExtra,
	['props.seedName']=props.seedName,
	['props.growBack']=props.growBack,
	['vegNum']=vegNum,
	})
	
	if props.vegetableName then
		sendHarvestToContainers(player, itemCont, props.vegetableName, vegNum)
		if data['booster'] and data['booster'] > 1 then
			local boost = math.ceil(vegNum*data['booster'])
			sendHarvestToContainers(player, itemCont, props.vegetableName, boost)
		end
	end
	
	if props.produceExtra then
		sendHarvestToContainers(player, itemCont, props.produceExtra, vegNum)
	end
			
	local seedAmount = 0
	if luaObject.hasSeed then
		local seedPerVeg = props.seedPerVeg or 0.5
		local number = math.max(tonumber(math.floor(numberOfVeg * seedPerVeg)), 1)
		if data['replant'] and not props.growBack then
			number = math.max(0, number-1)
			seedAmount = 1
		end
		sendHarvestToContainers(player, itemCont, props.seedName, number)
	end

	local extra = getExtraItems(luaObject)
	if extra and player then
		for n=1,#extra do
			local veg = extra[n]
			if type(veg) == "string" then
				sendHarvestToContainers(player, itemCont, veg, extra[n+1])
			end
		end
	end

	luaObject.hasVegetable = false
	luaObject.hasSeed = false

	if props.growBack then
		luaObject.nbOfGrow = props.growBack
		luaObject.fertilizer = 0;
		self:growPlant(luaObject, nil, true)
		local sprite = farming_vegetableconf.getSpriteName(luaObject)
		if sprite then luaObject:setSpriteName(sprite) end
		luaObject:saveData()
	elseif data['replant'] and props.seedName and itemCont:getCountType(props.seedName)+seedAmount > 0 then
		if seedAmount == 0 then
			local seed = itemCont:getFirstType(props.seedName)
			if seed then
				itemCont:Remove(seed)
				sendRemoveItemFromContainer(itemCont, seed)
			end
		end
		luaObject.nbOfGrow = 1; luaObject.fertilizer = 0; luaObject.health = 100; luaObject.waterLvl = 0;
		luaObject.aphidLvl = 0; luaObject.mildewLvl = 0; luaObject.fliesLvl = 0; luaObject.slugsLvl = 0;
		luaObject:saveData()
	else
	    luaObject:harvestThis()
		--self:removePlant(luaObject)
	end
end

local ogSFSHarvest = SFarmingSystem.harvest
function SFarmingSystem:harvest(luaObject, player)
	--print("SFarmingSystem:harvest - Start")
	local override
	local item = player and player.getPrimaryHandItem and player:getPrimaryHandItem()
	if item and luaObject.typeOfSeed then
		--print("SFarmingSystem:harvest - Player")
		local data = LSUtil.getInventionItemData(item)
		if data and item:getType() == 'Harvester' then
			--print("SFarmingSystem:harvest - Data, Item")
			local itemCont = item.getInventory and item:getInventory()
			if itemCont then
				--print("SFarmingSystem:harvest - ItemCont")
				override = true
				harvesterFarming(self, luaObject, player, data, itemCont)
			end
		end
	end
	if not override then
		local extra = getExtraItems(luaObject)
		if extra and player then
			for n=1,#extra do
				local veg = extra[n]
				if type(veg) == "string" then
					local items = player:getInventory():AddItems(veg, extra[n+1])
					sendAddItemsToContainer(player:getInventory(), items)
				end
			end
		end
		ogSFSHarvest(self, luaObject, player)
	end	
end
