require "TimedActions/ProjectArcade_PunchingTimedAction"
require "ProjectArcade_Currency"
require "ProjectArcade_HighscoreUI"

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

local function PA_AddLineToChat(text)
    if not ISChat or not ISChat.instance or not ISChat.instance.chatText then return end

    local msgText = tostring(text or "")
    local message = {
        getText = function(_) return msgText end,
        getTextWithPrefix = function(_) return msgText end,
        isServerAlert = function(_) return false end,
        isShowAuthor = function(_) return false end,
        getAuthor = function(_) return "" end,
        setShouldAttractZombies = function(_) return false end,
        setOverHeadSpeech = function(_) return false end,
    }

    ISChat.addLineInChat(message, 0)
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "ProjectArcade" then return end
    if not args then return end

    if command == "PunchingHSResult" then
        if not args.isHighscore then return end

        if ProjectArcade_HighscoreUI and ProjectArcade_HighscoreUI.Show then
            ProjectArcade_HighscoreUI.Show(tonumber(args.score) or 0, args.showKind or "male")
        end

        local player = getPlayer and getPlayer() or nil
        if player and PA_PlayOneShotAtCharacter then
            PA_PlayOneShotAtCharacter(player, "PAhighscore")
        end

        return
    end
	
	if command == "PunchingSendHighScores" then
        local player = getPlayer and getPlayer() or nil
        if not player then return end

			local male = tonumber(args.male) or 0
			local fem  = tonumber(args.female) or 0

			if male <= 0 then
				player:Say(safeGetText("ContextMenu_ProjectArcade_HighScoreMale_NoName"))
			else
				local maleName = args.maleName or safeGetText("ContextMenu_ProjectArcade_None")
				player:Say(safeGetText("ContextMenu_ProjectArcade_HighScoreMale", tostring(male), tostring(maleName)))
			end

			if fem <= 0 then
				player:Say(safeGetText("ContextMenu_ProjectArcade_HighScoreFemale_NoName"))
			else
				local femName = args.femaleName or safeGetText("ContextMenu_ProjectArcade_None")
				player:Say(safeGetText("ContextMenu_ProjectArcade_HighScoreFemale", tostring(fem), tostring(femName)))
			end

    end
	
    if command == "PunchingResetHSResult" then
        local player = getPlayer and getPlayer() or nil
        if not player then return end

        if args and args.ok then
            player:Say(safeGetText("ContextMenu_ProjectArcade_PunchScoresReset"))
        else
            player:Say(safeGetText("ContextMenu_ProjectArcade_AdminOnly"))
        end
        return
    end

    if command == "PunchingAnnounceHighScore" then
        PA_AddLineToChat(args.msg)
        return
    end
end)

local function PA_AddLineToChat(text, author)
    if not ISChat or not ISChat.instance or not ISChat.instance.chatText then return end

    local options = {
        showTime = false,
        serverAlert = false,
        showAuthor = false,
    }

    local msgText = tostring(text or "")
    local msgAuthor = tostring(author or "")

    local message = {
        getText = function(_) return msgText end,
        getTextWithPrefix = function(_) return msgText end,
        isServerAlert = function(_) return options.serverAlert end,
        isShowAuthor = function(_) return options.showAuthor end,
        getAuthor = function(_) return msgAuthor end,
        setShouldAttractZombies = function(_) return false end,
        setOverHeadSpeech = function(_) return false end,
    }

    ISChat.addLineInChat(message, 0)
end

local function isDebugMode()
    
    if isDebugEnabled and isDebugEnabled() then
        return true
    end

    
    if getCore and getCore().getDebug and getCore():getDebug() then
        return true
    end

    return false
end

local function isPlayerAdmin(playerObj)
    if not playerObj then return false end

    if isClient() then
        if playerObj.getAccessLevel then
            local ok, access = pcall(playerObj.getAccessLevel, playerObj)
            if ok and access and tostring(access) == "admin" then
                return true
            end
        end
        return false
    end

    if isServer() then
        if playerObj.getAccessLevel then
            local ok, access = pcall(playerObj.getAccessLevel, playerObj)
            if ok and access and tostring(access) == "admin" then
                return true
            end
        end
    end

    return false
end

local function onResetHighScores(worldobjects, playerObj, machineObj)
    if not playerObj then return end
    if not isPlayerAdmin(playerObj) then return end

    if isClient() and sendClientCommand then
        sendClientCommand("ProjectArcade", "PunchingResetHS", {})
        return
    end

    local g = ModData.getOrCreate("ProjectArcade")

    g.PA_Punch_HS_Male = 0
    g.PA_Punch_HS_MaleName = safeGetText("ContextMenu_ProjectArcade_None")

    g.PA_Punch_HS_Female = 0
    g.PA_Punch_HS_FemaleName = safeGetText("ContextMenu_ProjectArcade_None")

    if ModData.transmit then
        pcall(ModData.transmit, "ProjectArcade")
    end

    playerObj:Say(safeGetText("ContextMenu_ProjectArcade_PunchScoresReset"))
end

local PUNCH_SPRITES = {
    
    "pa_recreational_0",
    
    "pa_recreational_1",
}

local GROUP_NAMES = {
    "arcade_punching",
}

local BYPASS_COOLDOWN = true

local COOLDOWN_MS = 24 * 60 * 60 * 1000

local function tableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

local function getSpriteName(obj)
    if not obj or not obj.getSprite then return nil end
    local ok, sp = pcall(obj.getSprite, obj)
    if not ok or not sp or not sp.getName then return nil end
    local ok2, name = pcall(sp.getName, sp)
    if not ok2 then return nil end
    return name
end


local function tryGetProperties(obj)
    if not obj or not obj.getProperties then return nil end
    local ok, props = pcall(obj.getProperties, obj)
    if not ok then return nil end
    return props
end

local function hasProp(props, k)
    if not props then return false end

    
    if props.Is then
        local ok, res = pcall(props.Is, props, k)
        if ok and res ~= nil then return res == true end
    end

    
    if props.Val then
        local ok, res = pcall(props.Val, props, k)
        if ok and res ~= nil and tostring(res) ~= "" then
            return true
        end
    end

    return false
end

local function propVal(props, k)
    if not props then return nil end
    if props.Val then
        local ok, res = pcall(props.Val, props, k)
        if ok then return res end
    end
    return nil
end

local function isPunchMachine(obj)
    if not obj then return false end

    local props = tryGetProperties(obj)

    local groupName = (hasProp(props, "GroupName") and propVal(props, "GroupName")) or nil
    if groupName and tableContains(GROUP_NAMES, tostring(groupName)) then
        return true
    end

    local spriteName = getSpriteName(obj)
    if spriteName and tableContains(PUNCH_SPRITES, spriteName) then
        return true
    end

    return false
end


local function getFrontSquare(obj)
    if not obj or not obj.getSquare then return nil end
    local ok, sq = pcall(obj.getSquare, obj)
    if not ok or not sq then return nil end

    local spriteName = getSpriteName(obj)

    
    if spriteName == PUNCH_SPRITES[1] then
        return sq:getS()
    end

    
    if spriteName == PUNCH_SPRITES[2] then
        return sq:getE()
    end

    
    return nil
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

local function getPlayerKey(player)
    if not player then return "unknown" end
    if player.getUsername and player:getUsername() then
        return "u:" .. tostring(player:getUsername())
    end
    local d = player.getDescriptor and player:getDescriptor() or nil
    if d and d.getForename and d:getForename() then
        return "n:" .. tostring(d:getForename())
    end
    return "unknown"
end

local function canUse(player)
    if BYPASS_COOLDOWN then
        return true
    end

    local g = ModData.getOrCreate("ProjectArcade")
    g.PA_Punch_LastUse = g.PA_Punch_LastUse or {}

    local key = getPlayerKey(player)
    local last = g.PA_Punch_LastUse[key]
    if not last then return true end

    local now = getTimestampMs()
    return (now - last) >= COOLDOWN_MS
end

local function markUse(player)
    local g = ModData.getOrCreate("ProjectArcade")
    g.PA_Punch_LastUse = g.PA_Punch_LastUse or {}

    local key = getPlayerKey(player)
    g.PA_Punch_LastUse[key] = getTimestampMs()
end

local function sayHighScores(player)
    local g = ModData.getOrCreate("ProjectArcade")

    local male = g.PA_Punch_HS_Male or 0
    local maleName = g.PA_Punch_HS_MaleName or safeGetText("ContextMenu_ProjectArcade_None")

    local fem = g.PA_Punch_HS_Female or 0
    local femName = g.PA_Punch_HS_FemaleName or safeGetText("ContextMenu_ProjectArcade_None")

    player:Say(safeGetText("ContextMenu_ProjectArcade_HighScoreMale", tostring(male), tostring(maleName)))
    player:Say(safeGetText("ContextMenu_ProjectArcade_HighScoreFemale", tostring(fem), tostring(femName)))
end

	local function onTryStrength(worldobjects, playerObj, machineObj)
		if not playerObj or not machineObj then return end

	if not machineHasPower(machineObj) then
		playerObj:Say(getText("ContextMenu_ProjectArcade_NeedPower"))
		return
	end

	if not canUse(playerObj) then
		playerObj:Say(safeGetText("ContextMenu_ProjectArcade_PunchCooldown"))
		return
	end

	local front = getFrontSquare(machineObj)
	if front and front ~= playerObj:getSquare() then
		ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, front))
	end

	markUse(playerObj)

	
	ISTimedActionQueue.add(ProjectArcade_Currency.CheckAndQueueAction:new(
		playerObj,
		ProjectArcade_Currency.Config.Cost,
		ProjectArcade_Currency.Config.CurrencyFullType,
		ProjectArcade_Currency.Config.DebugFreePlay,
		ProjectArcade_Currency.Config.NoCoinText,
		function()
			ISTimedActionQueue.add(ProjectArcade_PunchingTimedAction:new(
				playerObj,
				machineObj,
				ProjectArcade_Currency.Config.Cost,
				ProjectArcade_Currency.Config.CurrencyFullType,
				ProjectArcade_Currency.Config.DebugFreePlay
			))
		end
	))

end

local function onViewHighScore(worldobjects, playerObj, machineObj)
    if not playerObj then return end

    if isClient() and sendClientCommand then
        sendClientCommand("ProjectArcade", "PunchingRequestHS", {})
        return
    end

    sayHighScores(playerObj)
end


local function doPunchMenu(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end

    local machineObj = nil
    for _, obj in ipairs(worldobjects) do
        if isPunchMachine(obj) then
            machineObj = obj
            break
        end
    end
    if not machineObj then return end

	
	local rootOpt = context:addOption("Punching Machine", worldobjects, nil)

	
	local subMenu = ISContextMenu:getNew(context)
	context:addSubMenu(rootOpt, subMenu)

	
	local iconTex = getTexture(PUNCH_SPRITES[1]) 
	if iconTex then
		rootOpt.iconTexture = iconTex
	end

	subMenu:addOption(safeGetText("ContextMenu_ProjectArcade_TryStrength"), worldobjects, onTryStrength, playerObj, machineObj)
	subMenu:addOption(safeGetText("ContextMenu_ProjectArcade_ViewHighScore"), worldobjects, onViewHighScore, playerObj, machineObj)

	if isPlayerAdmin(playerObj) then
		subMenu:addOption(safeGetText("ContextMenu_ProjectArcade_ResetHighScores"), worldobjects, onResetHighScores, playerObj, machineObj)
	end

end

Events.OnPreFillWorldObjectContextMenu.Add(doPunchMenu)
