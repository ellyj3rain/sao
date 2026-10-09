local MODULE = "ProjectArcade"

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
local function chargeCoins(playerObj, cost, currencyFullType)
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

    if command == "PayCoins" then
        local nonce = args and args.nonce
        local cost  = args and args.cost
        local ctype = "Base.SilverCoin"  -- CoinPusher is always SilverCoin

        local ok = chargeCoins(playerObj, cost, ctype)

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
        local cost = args and args.cost
        local ctype = "Base.SilverCoin"  -- CoinPusher is always SilverCoin
        local obj = findCoinPusherAt(x, y, z, sprite)
        if not obj then
            sendServerCommand(playerObj, MODULE, "CoinPusherPlayResult", { ok=false, reason="nomachine" })
            return
        end

        local okPay = chargeCoins(playerObj, cost, ctype)
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
