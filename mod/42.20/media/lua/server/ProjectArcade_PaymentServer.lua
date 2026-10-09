-- Integrated source: ProjectArcade; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
local MODULE = "ProjectArcade"
local chargeCoins

-- Only this server file holds paid claw attempts. The client receives an opaque
-- identifier; it cannot create or move an attempt to another player or machine.
ProjectArcade_ClawPayments = {}
local clawAttempts = {}
local clawNonces = setmetatable({}, { __mode = "k" })
local nextClawAttempt = 0
local CLAW_ATTEMPT_LIFETIME_MS = 120000

local function serverNowMs()
    if getTimestampMs then
        local ms = tonumber(getTimestampMs())
        if ms then return ms end
    end
    if getTimestamp then
        local seconds = tonumber(getTimestamp())
        if seconds then return seconds * 1000 end
    end
    return nil
end

local function selectedCurrency()
    local ft = SandboxVars and SandboxVars.ProjectArcade
        and SandboxVars.ProjectArcade.CurrencyFullType
    if type(ft) == "string" then
        ft = ft:gsub("^%s+", ""):gsub("%s+$", "")
        if ft ~= "" then
            local sm = getScriptManager and getScriptManager()
            if sm and sm.FindItem and sm:FindItem(ft) then return ft end
        end
    end
    return "Base.SilverCoin"
end

local CLAW_DIRECTIONS = {
    pa_recreational_2 = "getS",
    pa_recreational_3 = "getE",
    pa_recreational_4 = "getN",
    pa_recreational_5 = "getW",
}

local function clawDirection(sprite)
    if not sprite or not sprite.getName then return nil, nil end
    local name = sprite:getName()
    local direction = CLAW_DIRECTIONS[name]
    if direction then return name, direction end

    -- The source menu also accepts GroupName arcade_clawmachine, where the
    -- orientation is still encoded in one of the four source sprite names.
    local props = sprite.getProperties and sprite:getProperties()
    if not props or not props.has or not props.get
        or not props:has("GroupName") or props:get("GroupName") ~= "arcade_clawmachine"
        or type(name) ~= "string" then return nil, nil end
    for candidate, method in pairs(CLAW_DIRECTIONS) do
        if name:find(candidate, 1, true) then
            if direction then return nil, nil end
            direction = method
        end
    end
    if not direction then return nil, nil end
    return name, direction
end

local function machineHasPower(machine)
    local square = machine and machine:getSquare()
    if not square then return false end
    if square:haveElectricity() then return true end
    local gt = GameTime and GameTime.getInstance and GameTime:getInstance()
    local shutModifier = SandboxVars and SandboxVars.ElecShutModifier
    return gt ~= nil and type(shutModifier) == "number" and shutModifier > -1
        and gt:getNightsSurvived() < shutModifier
end

local function validInteger(value)
    return type(value) == "number" and value == math.floor(value)
end

local function resolveClaw(x, y, z, index)
    if not validInteger(x) or not validInteger(y) or not validInteger(z)
        or not validInteger(index) or index < 0 then return nil end
    local cell = getCell and getCell()
    local square = cell and cell:getGridSquare(x, y, z)
    local objects = square and square:getObjects()
    if not objects or index >= objects:size() then return nil end
    local machine = objects:get(index)
    if not machine or not machine.getSquare or machine:getSquare() ~= square
        or not machine.getSprite then return nil end
    local sprite, direction = clawDirection(machine:getSprite())
    if not direction then return nil end
    local front
    if direction == "getS" then
        front = square:getS()
    elseif direction == "getE" then
        front = square:getE()
    elseif direction == "getN" then
        front = square:getN()
    else
        front = square:getW()
    end
    if not front then return nil end
    return machine, square, sprite, front
end

local function playerAtFront(player, front)
    return player ~= nil and player.isDead and not player:isDead()
        and player.getSquare and player:getSquare() == front
end

local function validAttemptScene(row, player)
    if not playerAtFront(player, row.front) then return false end
    local machine, square, sprite, front =
        resolveClaw(row.x, row.y, row.z, row.index)
    return machine == row.machine and square == row.square
        and sprite == row.sprite and front == row.front
        and machineHasPower(machine)
end

local function purgeExpired(now)
    for id, row in pairs(clawAttempts) do
        if now > row.expiresAt then clawAttempts[id] = nil end
    end
end

function ProjectArcade_ClawPayments.consume(player, attemptId)
    if type(attemptId) ~= "string" then return false end
    local row = clawAttempts[attemptId]
    if not row or row.player ~= player or row.completed ~= true then return false end
    -- Remove first. A callback, failed roll or failed inventory add cannot
    -- make a second award from this payment.
    clawAttempts[attemptId] = nil
    local now = serverNowMs()
    return now ~= nil and now <= row.expiresAt and validAttemptScene(row, player)
end

local function liveClawAttempt(player, attemptId)
    if type(attemptId) ~= "string" then return nil end
    local row = clawAttempts[attemptId]
    if not row or row.player ~= player then return nil end
    local now = serverNowMs()
    if not now or now > row.expiresAt or not validAttemptScene(row, player) then
        return nil
    end
    return row
end

-- The native multiplayer timed-action receiver calls these on the server.
-- Payment alone cannot authorize a prize roll.
function ProjectArcade_ClawPayments.begin(player, attemptId, machine, cost, currency)
    local row = liveClawAttempt(player, attemptId)
    if not row or row.started or row.completed or row.machine ~= machine
        or row.cost ~= cost or row.currencyFullType ~= currency then return false end
    row.started = true
    return true
end

function ProjectArcade_ClawPayments.complete(player, attemptId)
    local row = liveClawAttempt(player, attemptId)
    if not row or row.started ~= true or row.completed then return false end
    row.completed = true
    return true
end

function ProjectArcade_ClawPayments.stop(player, attemptId)
    local row = clawAttempts[attemptId]
    if row and row.player == player and row.completed ~= true then
        clawAttempts[attemptId] = nil
    end
end

local function payClaw(player, args)
    local nonce = args and args.nonce
    local result = { nonce = nonce, ok = false }
    if type(nonce) ~= "string" or nonce == "" or #nonce > 128
        or not player then return result end
    local now = serverNowMs()
    if not now then return result end
    purgeExpired(now)
    local nonces = clawNonces[player]
    if nonces and nonces[nonce] then
        local old = nonces[nonce]
        if clawAttempts[old.attemptId] then
            return { nonce = nonce, ok = true, attemptId = old.attemptId,
                cost = 1, currencyFullType = old.currencyFullType }
        end
        return result
    end

    local machine, square, sprite, front = resolveClaw(
        args.x, args.y, args.z, args.index)
    if not machine or not playerAtFront(player, front)
        or not machineHasPower(machine) then return result end

    local currency = selectedCurrency()
    if not chargeCoins(player, 1, currency) then return result end

    nextClawAttempt = nextClawAttempt + 1
    local id = tostring(now) .. ":" .. tostring(nextClawAttempt)
    local expiresAt = now + CLAW_ATTEMPT_LIFETIME_MS
    clawAttempts[id] = { player = player, machine = machine, square = square,
        sprite = sprite, front = front, x = args.x, y = args.y, z = args.z,
        index = args.index, expiresAt = expiresAt, cost = 1,
        currencyFullType = currency }
    nonces = nonces or {}
    clawNonces[player] = nonces
    -- Keep the nonce until this server player object is collected. A delayed
    -- duplicate request cannot buy another attempt after the first expires.
    nonces[nonce] = { attemptId = id, currencyFullType = currency }
    return { nonce = nonce, ok = true, attemptId = id,
        cost = 1, currencyFullType = currency }
end

-- =========================
-- Utils: recursive item search (supports wallets/bags)
-- =========================
local function findItemRecursive(container, fullType)
    if not container or not fullType then return nil, nil end

    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it and it:getFullType() == fullType then
            return container, it
        end

        if it and it.IsInventoryContainer and it:IsInventoryContainer() then
            local inner = it:getInventory()
            if inner then
                local c, innerIt = findItemRecursive(inner, fullType)
                if c and innerIt then return c, innerIt end
            end
        end
    end

    return nil, nil
end

-- =========================
-- Utils: inventory
-- =========================
chargeCoins = function(playerObj, cost, currencyFullType)
    if not playerObj then return false end
    local inv = playerObj:getInventory()
    if not inv then return false end

    cost = tonumber(cost) or 1
    if cost < 1 then cost = 1 end

    currencyFullType = currencyFullType or "Base.SilverCoin"

    if inv:getCountTypeRecurse(currencyFullType) < cost then
        return false
    end

    for i = 1, cost do
        local c, coin = findItemRecursive(inv, currencyFullType)
        if not coin then return false end
        c:Remove(coin)
        sendRemoveItemFromContainer(c, coin)
    end

    return true
end

local function giveCoins(playerObj, amount, currencyFullType)
    if not playerObj then return false end
    local inv = playerObj:getInventory()
    if not inv then return false end

    amount = tonumber(amount) or 0
    if amount <= 0 then return false end

    currencyFullType = currencyFullType or "Base.SilverCoin"

    for i = 1, amount do
        local item = inv:AddItem(currencyFullType)
        if item then
            sendAddItemToContainer(inv, item)
        end
    end

    return true
end

-- =========================
-- Utils: find machine object
-- =========================
local function findCoinPusherAt(x, y, z, spriteName)
    local sq = getCell():getGridSquare(x, y, z)
    if not sq then return nil end

    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local obj = objs:get(i)
        if obj and obj.getSprite and obj:getSprite() and obj:getSprite():getName() == spriteName then
            return obj
        end
    end
    return nil
end

-- =========================
-- CoinPusher rules
-- =========================
local CP = {}

CP.MAX_LEVEL = 5

CP.LEVEL = {
    [1] = { chance = 60, rmin = 1, rmax = 2 },
    [2] = { chance = 45, rmin = 1, rmax = 3 },
    [3] = { chance = 28, rmin = 2, rmax = 5 },
    [4] = { chance = 16, rmin = 4, rmax = 9 },
    [5] = { chance = 12, rmin = 8, rmax = 16 },
}

CP.OTHER_UP_ON_PLAY = 40  
CP.OTHER_DOWN_ON_WIN = 20  
CP.WIN_RESET_TO_1_CH = 70  

local function clampLevel(lv)
    lv = tonumber(lv) or 1
    if lv < 1 then return 1 end
    if lv > CP.MAX_LEVEL then return CP.MAX_LEVEL end
    return lv
end

local function getState(machineObj)
    local md = machineObj:getModData()
    md.PA_CoinPusher = md.PA_CoinPusher or { levels = {1,1,1} }

    local L = md.PA_CoinPusher.levels
    if not L or #L < 3 then
        md.PA_CoinPusher.levels = {1,1,1}
    else
        L[1] = clampLevel(L[1])
        L[2] = clampLevel(L[2])
        L[3] = clampLevel(L[3])
    end

    return md.PA_CoinPusher
end

local function transmitState(machineObj)
    if machineObj.transmitModData then
        machineObj:transmitModData()
    end
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

local function resolvePlay(machineObj, pitId)
    local st = getState(machineObj)
    local levels = st.levels

    pitId = tonumber(pitId) or 1
    if pitId < 1 then pitId = 1 end
    if pitId > 3 then pitId = 3 end

    applyOtherUp(levels, pitId)

    local lv = clampLevel(levels[pitId])
    local rule = CP.LEVEL[lv] or CP.LEVEL[1]

    local win = (ZombRand(100) < rule.chance)
    local reward = 0

    if win then
        reward = ZombRand(rule.rmin, rule.rmax + 1)

        if ZombRand(100) < CP.WIN_RESET_TO_1_CH then
            levels[pitId] = 1
        else
            levels[pitId] = 2
        end

        applyOtherDownOnWin(levels, pitId)
    end

    st.levels = levels
    transmitState(machineObj)

    return win, reward, {levels[1], levels[2], levels[3]}
end

-- =========================
-- Commands
-- =========================
local function onClientCommand(module, command, playerObj, args)
    if module ~= MODULE then return end

    if command == "PayClawCoins" then
        local accepted, result = pcall(payClaw, playerObj, args)
        if not accepted then
            result = { nonce = args and args.nonce, ok = false }
        end
        sendServerCommand(playerObj, MODULE, "PayClawCoinsResult", result)
        return
    end

    if command == "PayCoins" then
        local nonce = args and args.nonce
        local ok = chargeCoins(playerObj, 1, selectedCurrency())

        sendServerCommand(playerObj, MODULE, "PayCoinsResult", {
            nonce = nonce,
            ok = ok == true,
        })
        return
    end

    if command == "CoinPusherGetState" then
        local x = args and args.x
        local y = args and args.y
        local z = args and args.z
        local sprite = args and args.spriteName

        local obj = findCoinPusherAt(x, y, z, sprite)
        if not obj then
            sendServerCommand(playerObj, MODULE, "CoinPusherState", { ok=false })
            return
        end

        local st = getState(obj)
        sendServerCommand(playerObj, MODULE, "CoinPusherState", {
            ok=true,
            levels = { st.levels[1], st.levels[2], st.levels[3] },
        })
        return
    end

    if command == "CoinPusherPlay" then
        local x = args and args.x
        local y = args and args.y
        local z = args and args.z
        local sprite = args and args.spriteName
        local pitId = args and args.pitId
        local ctype = "Base.SilverCoin"  -- CoinPusher is always SilverCoin
        local obj = findCoinPusherAt(x, y, z, sprite)
        if not obj then
            sendServerCommand(playerObj, MODULE, "CoinPusherPlayResult", { ok=false, reason="nomachine" })
            return
        end

        local okPay = chargeCoins(playerObj, 1, ctype)
        if not okPay then
            sendServerCommand(playerObj, MODULE, "CoinPusherPlayResult", { ok=false, reason="nocoin" })
            return
        end

        local win, reward, levels = resolvePlay(obj, pitId)

        if win and reward > 0 then
            giveCoins(playerObj, reward, ctype)
        end

        sendServerCommand(playerObj, MODULE, "CoinPusherPlayResult", {
            ok = true,
            win = win == true,
            reward = reward or 0,
            levels = levels,
            pitId = tonumber(pitId) or 1,
        })
        return
    end
end

Events.OnClientCommand.Add(onClientCommand)
