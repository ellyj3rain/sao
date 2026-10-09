-- Integrated source: LifestyleHobbies; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("LifestyleHobbies") then return end
--[[
LSAmbtMng = {}

function LSAmbtMng:addAmbt(ambt, func)


end

function LSAmbtMng:setEnable(ambt, isActive)
	if not self.character then return; end
	if isActive then table.insert(self.activeList, ambt); return; end
	if #self.activeList > 0 then
		for n=1, #self.activeList do
			if self.activeList[n] == ambt then table.remove(self.activeList, n); break; end
		end
	end
end

function LSAmbtMng:clear(player)
	self.character = player
	self.activeList = {}

end

return LSAmbtMng
]]--

LSAmbtMng = LSAmbtMng or {}
LSAmbtMng.min = 0

local function deepCopy(original)
    local copy = {}
    for key, value in pairs(original) do
        if type(value) == "table" then
            copy[key] = deepCopy(value)
        else
            copy[key] = value
        end
    end
    return copy
end

local function getCustomAmbtData(ambtName)
	local lsData = ModData.getOrCreate("LSDATA")
	if lsData and lsData["AMBT"] and lsData["AMBT"][ambtName] then
		return lsData["AMBT"][ambtName]
	end
	return false
end

LSAmbtMng.resetAmbt = function(playerObj, ambtName, forced)
	local customAmbt = getCustomAmbtData(ambtName)
	if customAmbt and customAmbt.custom and (not forced) then
		local playerAmbt = playerObj:getModData().Ambitions[ambtName]
		local activeException = SandboxVars.LSAmbt.ResetException and playerAmbt and playerAmbt.isActive
		if (customAmbt.resetF or (not playerAmbt) or (playerAmbt and (not playerAmbt.completed and not activeException))) then
			local t = deepCopy(customAmbt)
			playerObj:getModData().Ambitions[ambtName] = t
		end
		return
	end
	local AmbitionsList = require("Properties/Player/LSAmbitions")
	for k, v in ipairs(AmbitionsList) do
		if v.name and (v.name == ambtName) then
			local t = deepCopy(v)
			playerObj:getModData().Ambitions[v.name] = t
			break
		end
	end
	if isClient() then sendClientCommand(playerObj, "LS", "SavePlayerData", {playerObj:getModData()}); end
end

local function updateCS(character, div)
	local combatSpeed = character:getVariableFloat("CombatSpeed", 0)
	--print("updateCS old combatSpeed was: "..tostring(combatSpeed))
	combatSpeed = combatSpeed+(combatSpeed/div)
	combatSpeed = tonumber(string.format("%.2f", combatSpeed))
	--print("updateCS new combatSpeed is: "..tostring(combatSpeed))
	if combatSpeed == 0 then combatSpeed = 1.5; end
	character:setVariable("LSCSN", combatSpeed)
end


local function updateParams(character, ambitions)
	local csDiv = 0
	if LSAmbtMng.hasActiveCompleted(character, 'LSBladeMaster') then -- about 16%
		csDiv = csDiv+6
	elseif LSAmbtMng.hasActiveCompleted(character, 'LSLordDeath') then -- 10%, non cumulative with bm
		csDiv = csDiv+10
	end
	if csDiv ~= 0 then updateCS(character, csDiv); end
end

local function playerIsValid(character)
	if character and character:hasModData() and (not character:isDead()) and character:getModData().Ambitions then return true; end
	return false
end

local function updateAmbts()
	local character = getSpecificPlayer(0)
	if playerIsValid(character) then
		local items = character:getModData().Ambitions
		updateParams(character, items)
		for k, v in pairs(items) do
			if (not v.disable) and (v.completed or v.isActive or v.reset or v.isPassive or v.offBhv or v.isHidden) and LSAmbtMng[v.name] then
				if ((not v.completed) and (not v.isActive) and v.reset) then
					LSAmbtMng.resetAmbt(character, v.name, false)
				else
					LSAmbtMng[v.name](character, character:getModData().Ambitions[v.name])
				end
			end
		end	
	end
end

local function disableManager(playerObj)
	if not playerObj then playerObj = getSpecificPlayer(0); end
	if not playerIsValid(playerObj) then return; end
	playerObj:setVariable("LSCombatSpeed", "End")
	playerObj:setVariable("LSCSN", 1.5)
	playerObj:getModData().Ambitions = {}
	LSAmbtMng.LSEOMEnabled = false
	if isClient() then sendClientCommand(playerObj, "LS", "SavePlayerData", {playerObj:getModData()}); end
end
--[[
LSAmbtMng.hasActiveCompleted = function(character, ambtName)
	if not character:getModData().Ambitions then return false; end
	local ambt = character:getModData().Ambitions[ambtName]
	if ambt and (not ambt.disable) and ambt.completed and ambt.isActive then return true; end
	return false
end

LSAmbtMng.hasActive = function(character, ambtName)
	if not character:getModData().Ambitions then return false; end
	local ambt = character:getModData().Ambitions[ambtName]
	if ambt and (not ambt.disable) and (ambt.isActive or ambt.isPassive) then return true; end
	return false
end

LSAmbtMng.hasCompleted = function(character, ambtName)
	if not character:getModData().Ambitions then return false; end
	local ambt = character:getModData().Ambitions[ambtName]
	if ambt and (not ambt.disable) and ambt.completed then return true; end
	return false
end

LSAmbtMng.hasAmbition = function(character, ambtName)
	if not character:getModData().Ambitions then return false; end
	local ambt = character:getModData().Ambitions[ambtName]
	if ambt and (not ambt.disable) and (not ambt.isHidden) then return true; end
	return false
end
]]--
local function doHalo(player, ambt)
	HaloTextHelper.addGoodText(player, " <SIZE:large>".." <IMAGE:media/ui/Ambitions/"..ambt.texture..".png,32,32>".." <SPACE>"..getText(ambt.name).." <SPACE>"..getText("IGUI_LSAmbitions_Text_Completed"))
end

local function doPanel(player, ambt, isUnlock)
	local newPanel = LSAmbtNote:new(getCore():getScreenWidth()-460,(getCore():getScreenHeight()/6)-68,360,68, player, ambt, isUnlock)
	newPanel:initialise()
	newPanel:addToUIManager()
	return newPanel
end

local function getUnlockSound(soundName, key, limit)
	local sound = soundName
	if not LSAmbtMng[key] then LSAmbtMng[key] = 0; end
	LSAmbtMng[key] = math.ceil(LSAmbtMng[key]+1)
	if LSAmbtMng[key] > limit then LSAmbtMng[key] = 1; end
	sound = sound..tostring(LSAmbtMng[key])
	return sound
end

local function sendLog(player, ambt)
	local steamID, admin, characterName = getCurrentUserSteamID(), isAdmin(), player:getDescriptor():getForename().." "..player:getDescriptor():getSurname()
	sendClientCommand("LS", "logAmbition", {steamID, player:getUsername(), player:getDisplayName(), ambt.name, admin, characterName})
end

LSAmbtMng.doComplete = function(player, ambt)
	ambt.completed = true
	ambt.reset = false
	ambt.isHidden = false
	if LSAmbtMng.NotePanel then LSAmbtMng.NotePanel:destroy(false); end
	LSAmbtMng.NotePanel = doPanel(player, ambt, false)
	local sound = getUnlockSound("Ambt_Complete", 'CompleteSound', 3)
	getSoundManager():playUISound(sound)
	if isClient() then
		sendClientCommand(player, "LS", "SavePlayerData", {player:getModData()})
		sendLog(player, ambt)
	end
end

LSAmbtMng.doUnlock = function(player, ambt)
	ambt.delayUnlock = false
	if LSAmbtMng.NotePanel then return; end
	ambt.isHidden = false
	LSAmbtMng.NotePanel = doPanel(player, ambt, true)
	local sound = getUnlockSound("Ambt_Unlock", 'UnlockSound', 2)
	getSoundManager():playUISound(sound)
	if isClient() then sendClientCommand(player, "LS", "SavePlayerData", {player:getModData()}); end
end

local function addToTempLib(ambt1, ambt2)
	local ambitionsLib = require("Properties/Player/LSAmbitionsLib")
	local hasExclusive
	for k, v in pairs(ambitionsLib) do
		if v and v[1] and v[2] and
		((v[1] == ambt1) or v[1] == ambt2) and
		((v[2] == ambt1) or v[2] == ambt2) and
		(v[1] ~= v[2]) then
			hasExclusive = true; break
		end
	end
	if not hasExclusive then table.insert(ambitionsLib, {ambt1, ambt2}); end
end

local function setExclusives(realAmbt1, ambt1, realAmbt2, ambt2)
	if not realAmbt1.exclusive then realAmbt1.exclusive = {}; end
	if not realAmbt2.exclusive then realAmbt2.exclusive = {}; end
	if not realAmbt1.exclusive[ambt2] then table.insert(realAmbt1.exclusive, ambt2); end
	if not realAmbt2.exclusive[ambt1] then table.insert(realAmbt2.exclusive, ambt1); end
	--addToTempLib(ambt1, ambt2)
end

LSAmbtMng.setMutualExclusive = function(ambt1, ambt2)
	--print("attempting to set mutual exclusives...")
	if (not LSAmbtMng[ambt1]) or (not LSAmbtMng[ambt2]) then return; end
	local AmbitionsList = require("Properties/Player/LSAmbitions")
	local realAmbt1, realAmbt2
	for k, v in ipairs(AmbitionsList) do
		if (not realAmbt1) and (v.name == ambt1) then realAmbt1 = v; end
		if (not realAmbt2) and (v.name == ambt2) then realAmbt2 = v; end
		if realAmbt1 and realAmbt2 then break; end
	end
	if realAmbt1 and realAmbt2 then
		setExclusives(realAmbt1, ambt1, realAmbt2, ambt2)
		--print("SUCCESS")
	else
		--print("FAIL")
	end
end

--Events.OnPlayerUpdate.Add(LSAmbtMng.LSOPU)

local function customAmbtLoop(ogAmbt, playerData, num1, num2, numActive, numActiveComp)
	if not playerData.Ambitions then playerData.Ambitions = {}; end
	local playerAmbt = playerData.Ambitions[ogAmbt.name]
	local activeException = SandboxVars.LSAmbt.ResetException and playerAmbt and playerAmbt.isActive
	if ogAmbt.disable and playerAmbt then playerData.Ambitions[ogAmbt.name] = false; 
	elseif (not ogAmbt.disable) and (not playerAmbt) then
		local t = deepCopy(ogAmbt)
		playerData.Ambitions[ogAmbt.name] = t
	elseif (not ogAmbt.disable) and (ogAmbt.resetF or (not playerAmbt.completed and not activeException)) then
		local keys = {"name","cat","texture","goal1","goal2","goal3","goal4","goal5","goal6","isPassive","disable"}
		for _,key in pairs(keys) do
			if ogAmbt[key] ~= playerData.Ambitions[ogAmbt.name][key] then
				local t = deepCopy(ogAmbt)
				playerData.Ambitions[ogAmbt.name] = t
				break
			end
		end
	end
	if playerData.Ambitions[ogAmbt.name] and playerData.Ambitions[ogAmbt.name].isActive and playerData.Ambitions[ogAmbt.name].completed then num2 = num2+1;
		if num2 > numActiveComp then playerData.Ambitions[ogAmbt.name].isActive = false; end
	elseif playerData.Ambitions[ogAmbt.name] and playerData.Ambitions[ogAmbt.name].isActive then num1 = num1+1; num2 = num2+1;
		if (num1 > numActive) or (num2 > numActiveComp) then playerData.Ambitions[ogAmbt.name].isActive = false; end
	end
	return num1, num2
end

LSAmbtMng.LSCheckCustomAmbts = false

LSAmbtMng.LSEOM = function()
	local ambtSO = SandboxVars.LSAmbt.Toggle or false
	if not ambtSO then disableManager(false); Events.EveryOneMinute.Remove(LSAmbtMng.LSEOM); return; end
	LSAmbtMng.min = math.floor(LSAmbtMng.min+1)
	if LSAmbtMng.min > 4 then
		LSAmbtMng.min = 0
		updateAmbts()
	end
	if not LSAmbtMng.LSCheckCustomAmbts then
		local num1, num2, numActive, numActiveComp = 0, 0, SandboxVars.LSAmbt.MaxInProgress or 1, SandboxVars.LSAmbt.MaxTotal or 3
		if numActiveComp < numActive then numActiveComp = numActive; end
		local playerData = getPlayer():getModData()
		local AmbitionsList = require("Properties/Player/LSAmbitions")
		for k, v in ipairs(AmbitionsList) do
			local t = v
			local customAmbt = getCustomAmbtData(v.name)
			if customAmbt and customAmbt.custom then t = customAmbt; end
			num1, num2 = customAmbtLoop(t, playerData, num1, num2, numActive, numActiveComp)
		end	
		LSAmbtMng.LSCheckCustomAmbts = true
	end
end

local function LSAMBTWPResetData(player, dataName)
	local data = player:getModData()[dataName]
	if data and data[1] then
		if data[2] then data[1]:setConditionLowerChance(data[2]); end
		if data[3] then data[1]:setAimingTime(data[3]); end
		if data[4] then data[1]:setRecoilDelay(data[4]); end
		if data[5] then data[1]:setReloadTime(data[5]); end
		if data[6] then data[1]:setCriticalChance(data[6]); end
	end
	player:getModData()[dataName] = false
end

local function clearWPData(player)
	if player:getModData().LSCDWPC then LSAMBTWPResetData(player, 'LSCDWPC'); end
	if player:getModData().LSBMWPC then LSAMBTWPResetData(player, 'LSBMWPC'); end
	if player:getModData().LSTPWPC then LSAMBTWPResetData(player, 'LSTPWPC'); end
end

LSAmbtMng.onCreatePlayer = function(playerNum, playerObj)
	playerObj:setVariable("LSCombatSpeed", "End")
	playerObj:setVariable("LSCSN", 1.5)
	if not playerObj:getModData().Ambitions then playerObj:getModData().Ambitions = {}; end
	clearWPData(playerObj)
	
	local ambtSO = SandboxVars.LSAmbt.Toggle or false
	if not ambtSO then disableManager(playerObj); return; end
		
	if not LSAmbtMng.LSEOMEnabled then
		Events.EveryOneMinute.Add(LSAmbtMng.LSEOM)
		LSAmbtMng.LSEOMEnabled = true
	end
	--LSAmbtMng:clear(playerObj)
	--here: lock ambitions that fail player trait requirements;
end

LSAmbtMng.AmbitionsMenu = function()
	local player = getPlayer()
	local menu = LSAmbitionsMenu:new(getCore():getScreenWidth()/2-500,getCore():getScreenHeight()/2-350,650,650,player:getPlayerNum())
	menu:initialise()
	menu:addToUIManager()
end

Events.OnCreatePlayer.Add(LSAmbtMng.onCreatePlayer)
