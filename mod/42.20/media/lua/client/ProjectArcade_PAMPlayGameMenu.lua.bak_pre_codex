print("[ProjectArcade] ProjectArcade_PAMPlayGameMenu LOADED")

require "ISUI/ISWorldObjectContextMenu"
require "TimedActions/ISWalkToTimedAction"
require "TimedActions/ProjectArcade_PunchingTimedAction"
require "ProjectArcade_Currency"

local function loadTimedAction()
    local ok, err

    ok, err = pcall(function()
        require "TimedActions/ProjectArcade_PlayArcadeTimedAction"
    end)
    if ok and ProjectArcade_PlayArcadeTimedAction then
        print("[ProjectArcade] TimedAction loaded via TimedActions/ProjectArcade_PlayArcadeTimedAction")
        return true
    end
    print("[ProjectArcade] TimedAction require (TimedActions/...) failed: " .. tostring(err))

    ok, err = pcall(function()
        require "ProjectArcade_PlayArcadeTimedAction"
    end)
    if ok and ProjectArcade_PlayArcadeTimedAction then
        print("[ProjectArcade] TimedAction loaded via ProjectArcade_PlayArcadeTimedAction")
        return true
    end
    print("[ProjectArcade] TimedAction require (root client) failed: " .. tostring(err))

    print("[ProjectArcade] ERROR: TimedAction still nil after both requires.")
    return false
end

loadTimedAction()

local ArcadeSprites = {
    ["recreational_01_16"] = true, ["recreational_01_17"] = true, ["recreational_01_18"] = true, ["recreational_01_19"] = true,
    ["recreational_01_20"] = true, ["recreational_01_21"] = true, ["recreational_01_22"] = true, ["recreational_01_23"] = true,
    ["recreational_01_24"] = true, ["recreational_01_27"] = true,

    ["pa_arcades_0"] = true,  ["pa_arcades_1"] = true,  ["pa_arcades_2"] = true,  ["pa_arcades_3"] = true,
    ["pa_arcades_4"] = true,  ["pa_arcades_5"] = true,  ["pa_arcades_6"] = true,  ["pa_arcades_7"] = true,
    ["pa_arcades_8"] = true,  ["pa_arcades_9"] = true,  ["pa_arcades_10"] = true, ["pa_arcades_11"] = true,
    ["pa_arcades_12"] = true, ["pa_arcades_13"] = true, ["pa_arcades_14"] = true, ["pa_arcades_15"] = true,
    ["pa_arcades_16"] = true, ["pa_arcades_17"] = true, ["pa_arcades_18"] = true, ["pa_arcades_19"] = true,
	["pa_arcades_20"] = true, ["pa_arcades_21"] = true, ["pa_arcades_22"] = true, ["pa_arcades_23"] = true,
    ["pa_arcades_24"] = true, ["pa_arcades_25"] = true, ["pa_arcades_26"] = true, ["pa_arcades_27"] = true,
    ["pa_arcades_28"] = true, ["pa_arcades_29"] = true, ["pa_arcades_30"] = true, ["pa_arcades_31"] = true,
    ["pa_arcades_32"] = true, ["pa_arcades_33"] = true, ["pa_arcades_34"] = true, ["pa_arcades_35"] = true,
    ["pa_arcades_36"] = true, ["pa_arcades_37"] = true, ["pa_arcades_38"] = true, ["pa_arcades_39"] = true,
	
    ["pa_complex_0"] = true,
    ["pa_complex_1"] = true,
    ["pa_complex_2"] = true,
    ["pa_complex_3"] = true,
    ["pa_complex_4"] = true,
    ["pa_complex_5"] = true,
    ["pa_complex_6"] = true,
    ["pa_complex_7"] = true,
    ["pa_complex_8"] = true,
    ["pa_complex_9"] = true,
	
    ["pa_pinballs_0"] = true, ["pa_pinballs_3"] = true,
    ["pa_pinballs_4"] = true, ["pa_pinballs_7"] = true,
    ["pa_pinballs_8"] = true, ["pa_pinballs_11"] = true,
    ["pa_pinballs_12"] = true, ["pa_pinballs_15"] = true,
    ["pa_pinballs_16"] = true, ["pa_pinballs_19"] = true,
    ["pa_pinballs_20"] = true, ["pa_pinballs_21"] = true,
    ["pa_pinballs_22"] = true, ["pa_pinballs_23"] = true,
	["pa_pinballs_24"] = true, ["pa_pinballs_25"] = true,
    ["pa_pinballs_26"] = true, ["pa_pinballs_27"] = true,
}

local function getArcadeSouthSprite(spriteName)
    if not spriteName then return nil end

        if spriteName == "recreational_01_16" or spriteName == "recreational_01_17"
        or spriteName == "recreational_01_18" or spriteName == "recreational_01_19"
    then
        return "recreational_01_16"
    end

        if spriteName == "recreational_01_20" or spriteName == "recreational_01_21"
        or spriteName == "recreational_01_22" or spriteName == "recreational_01_23"
    then
        return "recreational_01_20"
    end

        if spriteName == "recreational_01_24" or spriteName == "recreational_01_27" then
        return "recreational_01_24"
    end

            if spriteName == "pa_arcades_0" or spriteName == "pa_arcades_1"
        or spriteName == "pa_arcades_2" or spriteName == "pa_arcades_3"
    then
        return "pa_arcades_0"
    end

        if spriteName == "pa_arcades_4" or spriteName == "pa_arcades_5"
        or spriteName == "pa_arcades_6" or spriteName == "pa_arcades_7"
    then
        return "pa_arcades_4"
    end

        if spriteName == "pa_arcades_8" or spriteName == "pa_arcades_9"
        or spriteName == "pa_arcades_10" or spriteName == "pa_arcades_11"
    then
        return "pa_arcades_8"
    end

        if spriteName == "pa_arcades_12" or spriteName == "pa_arcades_13"
        or spriteName == "pa_arcades_14" or spriteName == "pa_arcades_15"
    then
        return "pa_arcades_12"
    end
	
		if spriteName == "pa_arcades_16" or spriteName == "pa_arcades_17"
		or spriteName == "pa_arcades_18" or spriteName == "pa_arcades_19"
	then
		return "pa_arcades_16"
	end
	
	if spriteName == "pa_arcades_20" or spriteName == "pa_arcades_21"
		or spriteName == "pa_arcades_22" or spriteName == "pa_arcades_23"
	then
		return "pa_arcades_20"
	end
	
	if spriteName == "pa_arcades_24" or spriteName == "pa_arcades_25"
		or spriteName == "pa_arcades_26" or spriteName == "pa_arcades_27"
	then
		return "pa_arcades_24"
	end
	
	if spriteName == "pa_arcades_28" or spriteName == "pa_arcades_29"
		or spriteName == "pa_arcades_30" or spriteName == "pa_arcades_31"
	then
		return "pa_arcades_28"
	end
	
	if spriteName == "pa_arcades_32" or spriteName == "pa_arcades_33"
		or spriteName == "pa_arcades_34" or spriteName == "pa_arcades_35"
	then
		return "pa_arcades_32"
	end
	
	if spriteName == "pa_arcades_36" or spriteName == "pa_arcades_37"
		or spriteName == "pa_arcades_38" or spriteName == "pa_arcades_39"
	then
		return "pa_arcades_36"
	end
	

    if spriteName == "pa_complex_0" or spriteName == "pa_complex_1" then
        return "pa_complex_0"
    end
	
    if spriteName == "pa_complex_2" or spriteName == "pa_complex_3"
        or spriteName == "pa_complex_4" or spriteName == "pa_complex_5"
        or spriteName == "pa_complex_6" or spriteName == "pa_complex_7"
        or spriteName == "pa_complex_8" or spriteName == "pa_complex_9"
    then
        return "pa_complex_4"
    end

	
    if spriteName == "pa_pinballs_0" or spriteName == "pa_pinballs_3" then
        return "pa_pinballs_0"
    end

    if spriteName == "pa_pinballs_4" or spriteName == "pa_pinballs_7" then
        return "pa_pinballs_4"
    end
	
	if spriteName == "pa_pinballs_8" or spriteName == "pa_pinballs_11" then
        return "pa_pinballs_8"
    end

    if spriteName == "pa_pinballs_12" or spriteName == "pa_pinballs_15" then
        return "pa_pinballs_12"
    end

    if spriteName == "pa_pinballs_16" or spriteName == "pa_pinballs_19" then
        return "pa_pinballs_16"
    end

    if spriteName == "pa_pinballs_20" or spriteName == "pa_pinballs_23" then
        return "pa_pinballs_20"
    end
	
	if spriteName == "pa_pinballs_24" or spriteName == "pa_pinballs_27" then
        return "pa_pinballs_24"
    end

    return spriteName
end

local function isArcadeSprite(spriteName)
    return spriteName and ArcadeSprites[spriteName] == true
end

local function isPinballSprite(spriteName)
    return spriteName == "recreational_01_24"
        or spriteName == "recreational_01_27"
        or spriteName == "pa_pinballs_0"
        or spriteName == "pa_pinballs_3"
        or spriteName == "pa_pinballs_4"
        or spriteName == "pa_pinballs_7"
        or spriteName == "pa_pinballs_8"
        or spriteName == "pa_pinballs_11"
        or spriteName == "pa_pinballs_12"
        or spriteName == "pa_pinballs_15"
        or spriteName == "pa_pinballs_16"
        or spriteName == "pa_pinballs_19"
        or spriteName == "pa_pinballs_20"
        or spriteName == "pa_pinballs_23"
        or spriteName == "pa_pinballs_24"
        or spriteName == "pa_pinballs_27"
end

local function getComplexStarWarsTailSprite(spriteName)
    if not spriteName then return nil end

    if spriteName == "pa_complex_4" then
        return "pa_complex_4"
    end

    if spriteName == "pa_complex_3" then
        return "pa_complex_3"
    end

    if spriteName == "pa_complex_6" then
        return "pa_complex_6"
    end

    if spriteName == "pa_complex_9" then
        return "pa_complex_9"
    end

    return nil
end

local function getComplexStarWarsInteractionTile(square, spriteName)
    if not square or not spriteName then return nil end

    local tailSprite = getComplexStarWarsTailSprite(spriteName)
    if not tailSprite then return nil end

    if tailSprite == "pa_complex_4" then
        return square:getE()
    end

    if tailSprite == "pa_complex_3" then
        return square:getN()
    end

    if tailSprite == "pa_complex_6" then
        return square:getS()
    end

    if tailSprite == "pa_complex_9" then
        return square:getW()
    end

    return nil
end

local function frontTileFor(spriteName, square)
    if not square or not spriteName then return nil end

    if spriteName == "recreational_01_16" or spriteName == "recreational_01_20" or spriteName == "recreational_01_24" then
        return square:getS()
    end
    if spriteName == "recreational_01_17" or spriteName == "recreational_01_21" or spriteName == "recreational_01_27" then
        return square:getE()
    end
    if spriteName == "recreational_01_19" or spriteName == "recreational_01_23" then
        return square:getN()
    end
    if spriteName == "recreational_01_18" or spriteName == "recreational_01_22" then
        return square:getW()
    end

    if spriteName == "pa_arcades_0" or spriteName == "pa_arcades_4" or spriteName == "pa_arcades_8" or spriteName == "pa_arcades_12" or spriteName == "pa_arcades_16" or spriteName == "pa_arcades_20" or spriteName == "pa_arcades_24" or spriteName == "pa_arcades_28" or spriteName == "pa_arcades_32" or spriteName == "pa_arcades_36" then
        return square:getS()
    end
    if spriteName == "pa_arcades_1" or spriteName == "pa_arcades_5" or spriteName == "pa_arcades_9" or spriteName == "pa_arcades_13" or spriteName == "pa_arcades_17" or spriteName == "pa_arcades_21" or spriteName == "pa_arcades_25" or spriteName == "pa_arcades_29" or spriteName == "pa_arcades_33" or spriteName == "pa_arcades_37" then
        return square:getE()
    end
    if spriteName == "pa_arcades_2" or spriteName == "pa_arcades_6" or spriteName == "pa_arcades_10" or spriteName == "pa_arcades_14" or spriteName == "pa_arcades_18" or spriteName == "pa_arcades_22" or spriteName == "pa_arcades_26" or spriteName == "pa_arcades_30" or spriteName == "pa_arcades_34" or spriteName == "pa_arcades_38" then
        return square:getW()
    end
    if spriteName == "pa_arcades_3" or spriteName == "pa_arcades_7" or spriteName == "pa_arcades_11" or spriteName == "pa_arcades_15" or spriteName == "pa_arcades_19" or spriteName == "pa_arcades_23" or spriteName == "pa_arcades_27" or spriteName == "pa_arcades_31" or spriteName == "pa_arcades_35" or spriteName == "pa_arcades_39" then
        return square:getN()
    end


    if spriteName == "pa_complex_0" then
        return square:getS()
    end
    if spriteName == "pa_complex_1" then
        return square:getE()
    end

    -- Star Wars: siempre calcular desde la cola
    if spriteName == "pa_complex_2" or spriteName == "pa_complex_3"
        or spriteName == "pa_complex_4" or spriteName == "pa_complex_5"
        or spriteName == "pa_complex_6" or spriteName == "pa_complex_7"
        or spriteName == "pa_complex_8" or spriteName == "pa_complex_9"
    then
        return getComplexStarWarsInteractionTile(square, spriteName)
    end

    if spriteName == "pa_pinballs_0" then
        return square:getS()
    end
    if spriteName == "pa_pinballs_3" then
        return square:getE()
    end

    if spriteName == "pa_pinballs_4" then
        return square:getS()
    end
    if spriteName == "pa_pinballs_7" then
        return square:getE()
    end
    if spriteName == "pa_pinballs_8" then
        return square:getS()
    end
    if spriteName == "pa_pinballs_11" then
        return square:getE()
    end
    if spriteName == "pa_pinballs_12" then
        return square:getS()
    end
    if spriteName == "pa_pinballs_15" then
        return square:getE()
    end
    if spriteName == "pa_pinballs_16" then
        return square:getS()
    end
    if spriteName == "pa_pinballs_19" then
        return square:getE()
    end
    if spriteName == "pa_pinballs_20" then
        return square:getS()
    end
    if spriteName == "pa_pinballs_23" then
        return square:getE()
    end
	
    if spriteName == "pa_pinballs_24" then
        return square:getS()
    end
    if spriteName == "pa_pinballs_27" then
        return square:getE()
    end

    return nil
end

local function isComplexSprite(spriteName)
    return spriteName == "pa_complex_0" or spriteName == "pa_complex_1"
        or spriteName == "pa_complex_2" or spriteName == "pa_complex_3"
        or spriteName == "pa_complex_4" or spriteName == "pa_complex_5"
        or spriteName == "pa_complex_6" or spriteName == "pa_complex_7"
        or spriteName == "pa_complex_8" or spriteName == "pa_complex_9"
end

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

local function doBuildMenu(playerIndex, context, worldobjects, test)
    local player = getSpecificPlayer(playerIndex)
    if not player or not worldobjects then return end

    for _, wo in ipairs(worldobjects) do
        local sq = wo and wo:getSquare() or nil
        if sq then
            local objs = sq:getObjects()
            for i=0, objs:size()-1 do
                local obj = objs:get(i)
                local sp = obj and obj.getSprite and obj:getSprite() or nil
                local spriteName = sp and sp:getName() or nil
				
				if spriteName == "pa_complex_2"
                    or spriteName == "pa_complex_5"
                    or spriteName == "pa_complex_7"
                    or spriteName == "pa_complex_8"
                then
                    return
                end

                if isArcadeSprite(spriteName) then
                    if test then return true end

                    local label
                    if isPinballSprite(spriteName) then
                        label = getText("ContextMenu_PlayPinball") or safeGetText("ContextMenu_PlayPinball")
                    elseif isComplexSprite(spriteName) then
                        label = getText("ContextMenu_PlayArcade") or safeGetText("ContextMenu_PlayArcade")
                    else
                        label = getText("ContextMenu_PlayArcade") or safeGetText("ContextMenu_PlayArcade")
                    end

					local opt = context:addOption(label, obj, function()
						local square = obj:getSquare()
						if not square then return end

						if not machineHasPower(obj) then
							player:Say(getText("ContextMenu_ProjectArcade_NeedPower"))
							return
						end

						local objSprite = obj:getSprite()
						local objSpriteName = objSprite and objSprite:getName() or nil

						local front = frontTileFor(objSpriteName, square)

						if front then
							ISTimedActionQueue.add(ISWalkToTimedAction:new(player, front))
						end

						if ProjectArcade_PlayArcadeTimedAction and ProjectArcade_PlayArcadeTimedAction.new then
							ISTimedActionQueue.add(ProjectArcade_Currency.CheckAndQueueAction:new(
								player,
								ProjectArcade_Currency.Config.Cost,
								ProjectArcade_Currency.Config.CurrencyFullType,
								ProjectArcade_Currency.Config.DebugFreePlay,
								ProjectArcade_Currency.Config.NoCoinText,
								function()
									ISTimedActionQueue.add(ProjectArcade_PlayArcadeTimedAction:new(
										player,
										obj,
										2000,
										ProjectArcade_Currency.Config.Cost,
										ProjectArcade_Currency.Config.CurrencyFullType,
										ProjectArcade_Currency.Config.DebugFreePlay
									))
								end
							))
						else
							player:Say("TimedAction not loaded (check require)")
							print("[ProjectArcade] ERROR: TimedAction is nil (require failed or file not loaded).")
						end
					end)

					local iconSprite = getArcadeSouthSprite(spriteName)
					local iconTex = iconSprite and getTexture(iconSprite)
					if iconTex then
						opt.iconTexture = iconTex
					end

                    return
                end
            end
        end
    end
end

Events.OnPreFillWorldObjectContextMenu.Add(doBuildMenu)
