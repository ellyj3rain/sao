-- Integrated source: ProjectArcade; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
require "ISUI/ISInventoryPaneContextMenu"
-- ISWalkToTimedAction is an installed Build42 native global; no Lua module.
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ProjectArcade_ClawTimedAction"
require "TimedActions/ISBaseTimedAction"
require "ProjectArcade_Currency"

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

ProjectArcade_ClawMachine = ProjectArcade_ClawMachine or {}




ProjectArcade_ClawMachine.Sprites = {
    "pa_recreational_2", "pa_recreational_3", "pa_recreational_4", "pa_recreational_5"
}

local function machineHasPower(obj)
    if not obj then return false end

    local square = obj:getSquare()
    if not square then return false end

    if square:haveElectricity() then
        return true
    end

    local gt = GameTime and GameTime.getInstance and GameTime:getInstance() or nil
    local shutModifier = SandboxVars and SandboxVars.ElecShutModifier

    if gt and shutModifier and shutModifier > -1 then
        if gt:getNightsSurvived() < shutModifier then
            return true
        end
    end

    return false
end

local function getSpriteNameFromObject(obj)
    if not obj or type(obj) ~= "userdata" then return nil end
    if not obj.getSprite then return nil end
    local spr = obj:getSprite()
    if not spr then return nil end
    if spr.getName then
        return spr:getName()
    end
    return nil
end

local function getProps(obj)
    if not obj or type(obj) ~= "userdata" then return nil end
    if not obj.getSprite then return nil end
    local spr = obj:getSprite()
    if not spr then return nil end
    if spr.getProperties then
        return spr:getProperties()
    end
    return nil
end

local function hasProp(props, key)
    if not props then return false end

    
    if type(props) == "userdata" then
        if props.has then return props:has(key) end
        if props.Is then return props:Is(key) end
        return false
    end

    
    if type(props) == "table" then
        return props[key] ~= nil
    end

    return false
end

local function propVal(props, key)
    if not props then return nil end

    if type(props) == "userdata" then
        if props.get then return props:get(key) end
        if props.Val then return props:Val(key) end
        return nil
    end

    if type(props) == "table" then
        local v = props[key]
        if v == nil then return nil end
        return tostring(v)
    end

    return nil
end




local function isClawMachineObject(obj)
    local spriteName = getSpriteNameFromObject(obj)
    if not spriteName then return false end

    
    if spriteName == "pa_recreational_2" or spriteName == "pa_recreational_3"
        or spriteName == "pa_recreational_4" or spriteName == "pa_recreational_5"
    then
        return true
    end

    
    local props = getProps(obj)
    if not props then return false end

    local groupName = hasProp(props, "GroupName") and propVal(props, "GroupName") or nil
    if groupName == "arcade_clawmachine" then
        local matched = nil
        for _, candidate in ipairs(ProjectArcade_ClawMachine.Sprites) do
            if spriteName:find(candidate, 1, true) then
                if matched then return false end
                matched = candidate
            end
        end
        return matched ~= nil
    end

    return false
end

local function getFrontTileForClaw(square, spriteName)
    if not square or not spriteName then return nil end

    if string.find(spriteName, "pa_recreational_2") then return square:getS() end
    if string.find(spriteName, "pa_recreational_3") then return square:getE() end
    if string.find(spriteName, "pa_recreational_4") then return square:getN() end
    if string.find(spriteName, "pa_recreational_5") then return square:getW() end

    return nil
end

local function getClawSouthSprite(spriteName)
    
    
    if spriteName == "pa_recreational_2" or spriteName == "pa_recreational_3"
        or spriteName == "pa_recreational_4" or spriteName == "pa_recreational_5"
    then
        return "pa_recreational_2"
    end
    return spriteName
end

local function doClawMenu(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    if playerObj:isDead() then return end

    local clawObj = nil
    for _, obj in ipairs(worldobjects) do
        if isClawMachineObject(obj) then
            clawObj = obj
            break
        end
    end
    if not clawObj then return end

    local spriteName = getSpriteNameFromObject(clawObj)
    local square = clawObj:getSquare()
    if not square or not spriteName then return end

	local optionText = safeGetText("ContextMenu_ProjectArcade_PlayClawMachine")
	local opt = context:addOption(optionText, worldobjects, function()
		local currentSquare = clawObj and clawObj:getSquare() or nil
		local currentSpriteName = getSpriteNameFromObject(clawObj)

		if not currentSquare or not currentSpriteName or not isClawMachineObject(clawObj) then
			return
		end

		if not machineHasPower(clawObj) then
			playerObj:Say(getText("ContextMenu_ProjectArcade_NeedPower"))
			return
		end

		local front = getFrontTileForClaw(currentSquare, currentSpriteName)
		if not front then return end
		local function stillSelectedMachine()
			return not playerObj:isDead() and clawObj:getSquare() == currentSquare
				and getSpriteNameFromObject(clawObj) == currentSpriteName
				and isClawMachineObject(clawObj) and machineHasPower(clawObj)
				and getFrontTileForClaw(currentSquare, currentSpriteName) == front
				and playerObj:getSquare() == front
		end
		ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, front))

		local cost = ProjectArcade_Currency.Config.Cost
		local currencyType = ProjectArcade_Currency.Config.CurrencyFullType
		local freePlay = ProjectArcade_Currency.Config.DebugFreePlay
		ISTimedActionQueue.add(ProjectArcade_Currency.CheckAndQueueAction:new(
			playerObj,
			cost,
			currencyType,
			freePlay,
			ProjectArcade_Currency.Config.NoCoinText,
			function(receipt, chargedCost, chargedCurrency, serverAttemptId)
				if not stillSelectedMachine() then return end
				local paidCost = chargedCost or cost
				local paidCurrency = chargedCurrency or currencyType
				if not ProjectArcade_Currency.bindPaidReceipt(
					receipt, playerObj, clawObj, paidCost, paidCurrency, freePlay) then return end
				local action = ProjectArcade_ClawTimedAction:new(
					playerObj, clawObj, paidCost, paidCurrency, freePlay, serverAttemptId)
				action.paidReceipt = receipt
				ISTimedActionQueue.add(action)
			end,
			stillSelectedMachine,
			clawObj
		))
	end)
	
	local iconSprite = getClawSouthSprite(spriteName)
	local iconTex = iconSprite and getTexture(iconSprite)
	if iconTex then
		opt.iconTexture = iconTex
	end
end

ProjectArcade_ClawMachine.isMachine = isClawMachineObject
ProjectArcade_ClawMachine.front = function(obj)
    local square = obj and obj:getSquare()
    local sprite = getSpriteNameFromObject(obj)
    return square and getFrontTileForClaw(square, sprite) or nil
end
ProjectArcade_ClawMachine.power = machineHasPower
Events.OnPreFillWorldObjectContextMenu.Add(doClawMenu)
