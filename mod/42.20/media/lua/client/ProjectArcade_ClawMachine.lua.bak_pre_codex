require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISWalkToTimedAction"
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
        return true
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

		if not currentSquare or not currentSpriteName then
			return
		end

		if not machineHasPower(clawObj) then
			playerObj:Say(getText("ContextMenu_ProjectArcade_NeedPower"))
			return
		end

		local front = getFrontTileForClaw(currentSquare, currentSpriteName)
		if front then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, front))
		end

		ISTimedActionQueue.add(ProjectArcade_Currency.CheckAndQueueAction:new(
			playerObj,
			ProjectArcade_Currency.Config.Cost,
			ProjectArcade_Currency.Config.CurrencyFullType,
			ProjectArcade_Currency.Config.DebugFreePlay,
			ProjectArcade_Currency.Config.NoCoinText,
			function()
				ISTimedActionQueue.add(ProjectArcade_ClawTimedAction:new(
					playerObj,
					clawObj,
					ProjectArcade_Currency.Config.Cost,
					ProjectArcade_Currency.Config.CurrencyFullType,
					ProjectArcade_Currency.Config.DebugFreePlay
				))
			end
		))
	end)
	
	local iconSprite = getClawSouthSprite(spriteName)
	local iconTex = iconSprite and getTexture(iconSprite)
	if iconTex then
		opt.iconTexture = iconTex
	end
end

Events.OnPreFillWorldObjectContextMenu.Add(doClawMenu)