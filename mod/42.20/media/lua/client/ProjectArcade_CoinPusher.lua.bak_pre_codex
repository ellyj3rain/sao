require "ISUI/ISInventoryPaneContextMenu"
require "TimedActions/ISWalkToTimedAction"
require "TimedActions/ISTimedActionQueue"
require "ProjectArcade_Currency"
require "TimedActions/ProjectArcade_CoinPusherTimedAction"
require "ISUI/ProjectArcade_CoinPusherUI"

ProjectArcade_CoinPusher = ProjectArcade_CoinPusher or {}
ProjectArcade_CoinPusher.UI = nil

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
end

ProjectArcade_CoinPusher.Config = {
    Cost = 1,
    CurrencyFullType = "Base.SilverCoin",
    DebugFreePlay = false,

    Sprites = {
        South = "pa_recreational_6",
        East  = "pa_recreational_7",
    },

    ContextKey = "ContextMenu_ProjectArcade_PlayCoinPusher",
}

local CP = {
    MAX_LEVEL = 5,

    LEVEL = {
        [1] = { chance = 60, rmin = 1, rmax = 2 },
        [2] = { chance = 45, rmin = 1, rmax = 3 },
        [3] = { chance = 28, rmin = 2, rmax = 5 },
        [4] = { chance = 16, rmin = 4, rmax = 9 },
        [5] = { chance = 12, rmin = 8, rmax = 16 },
    },

    OTHER_UP_ON_PLAY   = 40,
    OTHER_DOWN_ON_WIN  = 20,
    WIN_RESET_TO_1_CH  = 70,
}

local function clampLevel(lv)
    lv = tonumber(lv) or 1
    if lv < 1 then return 1 end
    if lv > CP.MAX_LEVEL then return CP.MAX_LEVEL end
    return lv
end

local function getCoinPusherState(machineObj)
    local md = machineObj:getModData()
    md.PA_CoinPusher = md.PA_CoinPusher or { levels = {1,1,1} }

    local L = md.PA_CoinPusher.levels
    if not L or #L < 3 then
        md.PA_CoinPusher.levels = {1,1,1}
        L = md.PA_CoinPusher.levels
    end

    L[1] = clampLevel(L[1]); L[2] = clampLevel(L[2]); L[3] = clampLevel(L[3])
    return md.PA_CoinPusher
end

local function applyOtherUp(levels, playedId)
    for i=1,3 do
        if i ~= playedId then
            if ZombRand(100) < CP.OTHER_UP_ON_PLAY then
                levels[i] = clampLevel(levels[i] + 1)
            end
        end
    end
end

local function applyOtherDownOnWin(levels, playedId)
    for i=1,3 do
        if i ~= playedId then
            if ZombRand(100) < CP.OTHER_DOWN_ON_WIN then
                levels[i] = clampLevel(levels[i] - 1)
            end
        end
    end
end

local function resolvePlayLocal(machineObj, pitId)
    pitId = tonumber(pitId) or 1
    if pitId < 1 then pitId = 1 end
    if pitId > 3 then pitId = 3 end

    local st = getCoinPusherState(machineObj)
    local levels = st.levels

    -- jugar A => otros dos 40% suben
    applyOtherUp(levels, pitId)

    local lv = clampLevel(levels[pitId])
    local rule = CP.LEVEL[lv] or CP.LEVEL[1]

    local win = (ZombRand(100) < rule.chance)
    local reward = 0

    if win then
        reward = ZombRand(rule.rmin, rule.rmax + 1)

        -- descarga del pozo ganador a 1 o 2
        if ZombRand(100) < CP.WIN_RESET_TO_1_CH then
            levels[pitId] = 1
        else
            levels[pitId] = 2
        end

        applyOtherDownOnWin(levels, pitId)
    end

    st.levels = levels
    if machineObj.transmitModData then
        machineObj:transmitModData()
    end

    return win, reward, {levels[1], levels[2], levels[3]}
end


local function getSpriteNameFromObject(obj)
    if not obj or type(obj) ~= "userdata" then return nil end
    if not obj.getSprite then return nil end
    local spr = obj:getSprite()
    if not spr then return nil end
    if spr.getName then return spr:getName() end
    return nil
end

local function isCoinPusherObject(obj)
    local spriteName = getSpriteNameFromObject(obj)
    if not spriteName then return false end

    for _, spr in pairs(ProjectArcade_CoinPusher.Config.Sprites) do
        if spriteName == spr then
            return true
        end
    end
    return false
end

local function giveCoins(playerObj, amount, currencyFullType)
    amount = tonumber(amount) or 0
    if amount <= 0 then return end

    currencyFullType = currencyFullType or ProjectArcade_CoinPusher.Config.CurrencyFullType

    if isClient() and not isServer() then
        sendClientCommand(playerObj, "ProjectArcade", "GiveCoins", {
            amount = amount,
            currencyFullType = currencyFullType,
        })
        return
    end

    local inv = playerObj and playerObj:getInventory()
    if not inv then return end

    for i = 1, amount do
        local item = inv:AddItem(currencyFullType)
        if isServer() and item then
            sendAddItemToContainer(inv, item)
        end
    end
end

function ProjectArcade_CoinPusher.OpenUI(playerObj, machineObj)
    if ProjectArcade_CoinPusher.UI then
        ProjectArcade_CoinPusher.UI:setVisible(false)
        ProjectArcade_CoinPusher.UI:removeFromUIManager()
        ProjectArcade_CoinPusher.UI = nil
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()

	local w, h = 952, 715
	local x = math.floor((sw - w) / 2)
	local y = math.floor((sh - h) / 2)

    local currencyType = ProjectArcade_CoinPusher.Config.CurrencyFullType

	local function onPlay(pitId)
		local sq = machineObj and machineObj:getSquare()
		if not sq then
			if ProjectArcade_CoinPusher.UI then ProjectArcade_CoinPusher.UI:close() end
			return
		end

		if isClient() and not isServer() then
			local spr = getSpriteNameFromObject(machineObj)

			sendClientCommand(playerObj, "ProjectArcade", "CoinPusherPlay", {
				x = sq:getX(), y = sq:getY(), z = sq:getZ(),
				spriteName = spr,
				pitId = pitId,
				cost = ProjectArcade_CoinPusher.Config.Cost,
				currencyFullType = currencyType,
			})
			return
		end

		ISTimedActionQueue.add(ProjectArcade_Currency.CheckAndQueueAction:new(
			playerObj,
			ProjectArcade_CoinPusher.Config.Cost,
			currencyType,
			ProjectArcade_CoinPusher.Config.DebugFreePlay,
			false, 
			function()
				local win, reward, levels = resolvePlayLocal(machineObj, pitId)

				if ProjectArcade_CoinPusher.UI and ProjectArcade_CoinPusher.UI.setPitLevels then
					ProjectArcade_CoinPusher.UI:setPitLevels(levels)
				end

				if ProjectArcade_CoinPusher.UI then
					ProjectArcade_CoinPusher.UI:showResultOverlay(win, reward)
				end
			end,
			function()
				if ProjectArcade_CoinPusher.UI then ProjectArcade_CoinPusher.UI:close() end
			end
		))
	end


	local function onReward(amount)
		if isClient() and not isServer() then
			return
		end

		giveCoins(playerObj, amount, currencyType)

		if ProjectArcade_CoinPusher.UI and ProjectArcade_CoinPusher.UI.updateTotalCoins then
			ProjectArcade_CoinPusher.UI:updateTotalCoins()
		end
	end

    local function onClose()
        ProjectArcade_CoinPusher.UI = nil
    end

    ProjectArcade_CoinPusher.UI = ProjectArcade_CoinPusherUI:new(
        x, y, w, h,
        playerObj, machineObj,
        currencyType,
        ProjectArcade_CoinPusher.Config.Cost,
        onPlay,
        onReward,
        onClose
    )

    ProjectArcade_CoinPusher.UI:initialise()
    ProjectArcade_CoinPusher.UI:addToUIManager()
    ProjectArcade_CoinPusher.UI:setVisible(true)

	if machineObj and (not isClient() or isServer()) then
		local st = getCoinPusherState(machineObj)
		if st and st.levels and ProjectArcade_CoinPusher.UI and ProjectArcade_CoinPusher.UI.setPitLevels then
			ProjectArcade_CoinPusher.UI:setPitLevels(st.levels)
		end
	end

    local sq = machineObj and machineObj:getSquare()
    if sq and isClient() and not isServer() then
		local spr = getSpriteNameFromObject(machineObj)

		sendClientCommand(playerObj, "ProjectArcade", "CoinPusherGetState", {
			x = sq:getX(), y = sq:getY(), z = sq:getZ(),
			spriteName = spr,
		})
    end
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

local function doCoinPusherMenu(player, context, worldobjects)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or playerObj:isDead() then return end

    local machineObj = nil
    for _, obj in ipairs(worldobjects) do
        if isCoinPusherObject(obj) then
            machineObj = obj
            break
        end
    end
    if not machineObj then return end

	local optionText = safeGetText(ProjectArcade_CoinPusher.Config.ContextKey)
	local opt = context:addOption(optionText, worldobjects, function()
		local currentSquare = machineObj and machineObj:getSquare() or nil
		if not currentSquare then
			return
		end

		local currentSpriteName = getSpriteNameFromObject(machineObj)

		if not machineHasPower(machineObj) then
			playerObj:Say(getText("ContextMenu_ProjectArcade_NeedPower"))
			return
		end

		local front = currentSquare:getS()
		if currentSpriteName == ProjectArcade_CoinPusher.Config.Sprites.East then
			front = currentSquare:getE()
		end

		if front then
			ISTimedActionQueue.add(ISWalkToTimedAction:new(playerObj, front))
		end

		ISTimedActionQueue.add(ProjectArcade_CoinPusherTimedAction:new(playerObj, machineObj, function()
			ProjectArcade_CoinPusher.OpenUI(playerObj, machineObj)
		end))
	end)

	local spr = getSpriteNameFromObject(machineObj) or ProjectArcade_CoinPusher.Config.Sprites.South
	local iconTex = getTexture(spr)
	if iconTex then
		opt.iconTexture = iconTex
	end
end

Events.OnPreFillWorldObjectContextMenu.Add(doCoinPusherMenu)

local function onServerCommand(module, command, args)
    if module ~= "ProjectArcade" then return end
    if not ProjectArcade_CoinPusher.UI then return end

    if command == "CoinPusherState" then
        if args and args.ok and args.levels then
            ProjectArcade_CoinPusher.UI:setPitLevels(args.levels)
        end
        return
    end

    if command == "CoinPusherPlayResult" then
        ProjectArcade_CoinPusher.UI:markServerResponse()

        if not args or not args.ok then
            ProjectArcade_CoinPusher.UI:close()
            return
        end

        if args.levels then
            ProjectArcade_CoinPusher.UI:setPitLevels(args.levels)
        end

        ProjectArcade_CoinPusher.UI:showResultOverlay(args.win == true, args.reward or 0)
        return
    end
end

Events.OnServerCommand.Add(onServerCommand)

