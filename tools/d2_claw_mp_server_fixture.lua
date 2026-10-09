-- Controlled server receivers for the packaged ProjectArcade payment and prize files.
local handlers = {}
require = function(name)
    if name == "ProjectArcade_PaymentServer" and not ProjectArcade_ClawPayments then
        error("payment server must load before prize server")
    end
    return nil
end
ISBaseTimedAction = {}
function ISBaseTimedAction:derive(name)
    local action = setmetatable({ Type = name }, { __index = self })
    action.__index = action
    return action
end
function ISBaseTimedAction:new(character)
    return setmetatable({ character = character }, self)
end
SAO = { SourceIntegration = { active = function(id) return id == "ProjectArcade" end } }
Events = { OnClientCommand = { Add = function(fn) handlers[#handlers + 1] = fn end } }
SandboxVars = { ElecShutModifier = -1, ProjectArcade = {} }
local now = 1000000
getTimestampMs = function() return now end
local nights = 1
GameTime = { getInstance = function() return { getNightsSurvived = function() return nights end } end }
local validItems = { ["Base.SilverCoin"] = true, ["Base.GoldCoin"] = true }
getScriptManager = function()
    return { FindItem = function(_, item) return validItems[item] and { type = item } or nil end }
end
ZombRand = function(a, b) return b and a or 99 end

local replies, removed, added = {}, {}, {}
sendServerCommand = function(player, module, command, payload)
    replies[#replies + 1] = { player = player, module = module,
        command = command, payload = payload }
end
sendRemoveItemFromContainer = function(_, item) removed[#removed + 1] = item end
sendAddItemToContainer = function(_, item) added[#added + 1] = item end

local world
getCell = function()
    return { getGridSquare = function(_, x, y, z)
        if world and world.square.x == x and world.square.y == y
            and world.square.z == z then return world.square end
        return nil
    end }
end

local function newScene(spriteName, powered)
    local fronts = {
        S = { tag = "S" }, E = { tag = "E" },
        N = { tag = "N" }, W = { tag = "W" },
    }
    local facing = ({ pa_recreational_2 = "S", pa_recreational_3 = "E",
        pa_recreational_4 = "N", pa_recreational_5 = "W" })[spriteName or "pa_recreational_2"] or "S"
    local front = fronts[facing]
    local square = { x = 10, y = 20, z = 0, powered = powered ~= false,
        front = front, objects = {} }
    function square:haveElectricity() return self.powered end
    function square:getS() return fronts.S end
    function square:getE() return fronts.E end
    function square:getN() return fronts.N end
    function square:getW() return fronts.W end
    function square:getObjects()
        return { size = function() return #self.objects end,
            get = function(_, index) return self.objects[index + 1] end }
    end
    local machine = { square = square, spriteName = spriteName or "pa_recreational_2",
        modData = {} }
    function machine:getSquare() return self.square end
    function machine:getSprite()
        return { getName = function() return self.spriteName end,
            getProperties = function() return nil end }
    end
    function machine:getModData() return self.modData end
    function machine:transmitModData() end
    square.objects[1] = machine
    world = { square = square, front = front, fronts = fronts, machine = machine }
    return world
end

local function newPlayer(currency, count)
    local items, awards = {}, {}
    for i = 1, count do
        items[#items + 1] = { fullType = currency,
            getFullType = function(self) return self.fullType end }
    end
    local inv = { items = items, awards = awards, failAdd = false }
    function inv:getCountTypeRecurse(fullType)
        local result = 0
        for _, item in ipairs(self.items) do
            if item.fullType == fullType then result = result + 1 end
        end
        return result
    end
    function inv:getItems()
        return { size = function() return #self.items end,
            get = function(_, index) return self.items[index + 1] end }
    end
    function inv:Remove(item)
        for index, candidate in ipairs(self.items) do
            if candidate == item then table.remove(self.items, index); return end
        end
        error("wrong coin removed")
    end
    function inv:AddItem(fullType)
        if self.failAdd then return nil end
        local item = { fullType = fullType,
            getDisplayName = function() return "Prize" end }
        self.awards[#self.awards + 1] = item
        return item
    end
    local player = { square = world.front, inv = inv, dead = false }
    function player:getSquare() return self.square end
    function player:isDead() return self.dead end
    function player:getInventory() return self.inv end
    return player, inv
end

local rollCount = 0
local nextPrize = "Base.Spiffo"
ProjectArcade_PrizeRegistry = { rollMerged = function()
    rollCount = rollCount + 1
    return nextPrize
end }
ProjectArcade_PrizeNet = { MODULE = "ProjectArcade", CMD_ROLL = "RollPrize",
    CMD_RESULT = "RollPrizeResult" }

local checks = 0
local function check(name, condition)
    if not condition then error("CLAW_MP:" .. name) end
    checks = checks + 1
    print("CHECK " .. name)
end
local function command(name, player, args)
    local before = #replies
    for _, handler in ipairs(handlers) do
        handler("ProjectArcade", name, player, args)
    end
    check(name .. "_single_reply", #replies == before + 1)
    local reply = replies[#replies]
    check(name .. "_target", reply.player == player and reply.module == "ProjectArcade")
    return reply.payload, reply.command
end
local function pay(player, nonce, index)
    local result, name = command("PayClawCoins", player,
        { nonce = nonce, x = 10, y = 20, z = 0, index = index or 0,
            cost = 0, currencyFullType = "Base.SilverCoin" })
    check("payment_command_name", name == "PayClawCoinsResult")
    check("payment_correlated", result.nonce == nonce)
    return result
end
local function prize(player, nonce, attemptId)
    local result, name = command("RollPrize", player,
        { nonce = nonce, attemptId = attemptId })
    check("prize_command_name", name == "RollPrizeResult")
    check("prize_correlated", result.nonce == nonce)
    return result
end

local function clawAction(player, payment, machine, cost, currency)
    return ProjectArcade_ClawTimedAction:new(player, machine or world.machine,
        cost == nil and payment.cost or cost,
        currency or payment.currencyFullType, false, payment.attemptId)
end

local function completePaid(player, payment, label)
    local action = clawAction(player, payment)
    action:serverStart()
    check(label .. "_server_started", action.startedPaid == true)
    check(label .. "_server_completed", action:complete() == true)
    return action
end

function __runClawMpServerCases()
    check("handlers_loaded", #handlers == 2
        and type(ProjectArcade_ClawPayments.consume) == "function"
        and type(ProjectArcade_ClawTimedAction.serverStart) == "function"
        and type(ProjectArcade_ClawTimedAction.complete) == "function"
        and type(ProjectArcade_ClawTimedAction.serverStop) == "function")
    newScene()
    local player, inv = newPlayer("Base.SilverCoin", 1)
    check("bare_roll_refused", prize(player, "bare", nil).ok == false
        and #inv.awards == 0 and rollCount == 0)
    check("wrong_index_refused", pay(player, "bad-index", 1).ok == false
        and #inv.items == 1)
    world.machine.spriteName = "not_a_claw"
    check("wrong_sprite_refused", pay(player, "bad-sprite").ok == false
        and #inv.items == 1)
    world.machine.spriteName = "pa_recreational_2"
    world.square.powered = false
    check("power_required_payment", pay(player, "no-power").ok == false
        and #inv.items == 1)
    world.square.powered = true
    player.square = { tag = "away" }
    check("front_required_payment", pay(player, "away").ok == false
        and #inv.items == 1)
    player.square = world.front
    player.dead = true
    check("living_player_required", pay(player, "dead").ok == false
        and #inv.items == 1)

    for _, row in ipairs({
        { sprite = "pa_recreational_2", front = "S" },
        { sprite = "pa_recreational_3", front = "E" },
        { sprite = "pa_recreational_4", front = "N" },
        { sprite = "pa_recreational_5", front = "W" },
    }) do
        newScene(row.sprite)
        player, inv = newPlayer("Base.SilverCoin", 1)
        player.square = world.fronts.S == world.front and world.fronts.E or world.fronts.S
        check(row.front .. "_wrong_front_refused", pay(player, "front-" .. row.front).ok == false
            and #inv.items == 1)
        player.square = world.fronts[row.front]
        local oriented = pay(player, "oriented-" .. row.front)
        check(row.front .. "_front_accepted", oriented.ok == true and #inv.items == 0)
        completePaid(player, oriented, row.front)
        check(row.front .. "_paid_award", prize(player, "oriented-roll-" .. row.front,
            oriented.attemptId).ok == true and #inv.awards == 1)
    end

    newScene()
    SandboxVars.ProjectArcade.CurrencyFullType = "  Base.GoldCoin  "
    player, inv = newPlayer("Base.GoldCoin", 2)
    local removedBefore = #removed
    local payment = pay(player, "gold")
    check("selected_currency_and_cost", payment.ok == true
        and payment.currencyFullType == "Base.GoldCoin" and payment.cost == 1
        and type(payment.attemptId) == "string" and #inv.items == 1
        and #removed == removedBefore + 1 and removed[#removed].fullType == "Base.GoldCoin")
    local repeated = pay(player, "gold")
    check("duplicate_payment_idempotent", repeated.ok == true
        and repeated.attemptId == payment.attemptId and #inv.items == 1)
    local beforeRoll = rollCount
    check("action_completion_required", prize(player, "gold-early", payment.attemptId).ok == false
        and #inv.awards == 0 and rollCount == beforeRoll)
    local other, otherInv = newPlayer("Base.GoldCoin", 1)
    local wrongActor = clawAction(other, payment)
    wrongActor:serverStart()
    check("wrong_actor_cannot_mark", wrongActor.startedPaid == false
        and wrongActor:complete() == false)
    local wrongMachine = clawAction(player, payment,
        { square = world.square, spriteName = world.machine.spriteName })
    wrongMachine:serverStart()
    check("wrong_machine_cannot_mark", wrongMachine.startedPaid == false
        and wrongMachine:complete() == false)
    local wrongCost = clawAction(player, payment, nil, 0)
    wrongCost:serverStart()
    check("wrong_cost_cannot_mark", wrongCost.startedPaid == false
        and wrongCost:complete() == false)
    local wrongCurrency = clawAction(player, payment, nil, nil, "Base.SilverCoin")
    wrongCurrency:serverStart()
    check("wrong_currency_cannot_mark", wrongCurrency.startedPaid == false
        and wrongCurrency:complete() == false)
    local legit = clawAction(player, payment)
    check("completion_before_start_refused", legit:complete() == false)
    legit:serverStart()
    check("valid_native_receiver_started", legit.startedPaid == true)
    check("started_action_cannot_roll", prize(player, "gold-started", payment.attemptId).ok == false
        and #inv.awards == 0 and rollCount == beforeRoll)
    check("valid_native_receiver_completed", legit:complete() == true)
    check("completion_not_repeated", legit:complete() == false)
    beforeRoll = rollCount
    local addedBefore = #added
    check("cross_actor_refused", prize(other, "cross", payment.attemptId).ok == false
        and #otherInv.awards == 0 and rollCount == beforeRoll)
    local won = prize(player, "won", payment.attemptId)
    check("paid_prize_awarded", won.ok == true and won.prizeType == "Base.Spiffo"
        and won.displayName == "Prize" and #inv.awards == 1 and #added == addedBefore + 1
        and rollCount == beforeRoll + 1)
    check("replayed_roll_refused", prize(player, "replay", payment.attemptId).ok == false
        and #inv.awards == 1 and rollCount == beforeRoll + 1)
    check("duplicate_payment_after_use_refused", pay(player, "gold").ok == false
        and #inv.items == 1)

    newScene()
    SandboxVars.ProjectArcade.CurrencyFullType = "Base.SilverCoin"
    player, inv = newPlayer("Base.SilverCoin", 2)
    local interrupted = pay(player, "interrupted")
    local repeatedPlay = pay(player, "repeat-play")
    check("interrupted_action_does_not_block_new_payment", interrupted.ok == true
        and repeatedPlay.ok == true and interrupted.attemptId ~= repeatedPlay.attemptId
        and #inv.items == 0)
    completePaid(player, repeatedPlay, "repeat_play")
    beforeRoll = rollCount
    check("repeat_play_awards_once", prize(player, "repeat-roll", repeatedPlay.attemptId).ok == true
        and #inv.awards == 1 and rollCount == beforeRoll + 1)
    check("repeat_play_replay_refused", prize(player, "repeat-replay", repeatedPlay.attemptId).ok == false
        and #inv.awards == 1 and rollCount == beforeRoll + 1)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "stopped")
    local stopped = clawAction(player, payment)
    stopped:serverStart()
    check("stopped_action_started", stopped.startedPaid == true)
    stopped:serverStop()
    check("stopped_action_cannot_complete", stopped:complete() == false)
    beforeRoll = rollCount
    check("stopped_action_cannot_roll", prize(player, "stopped-roll", payment.attemptId).ok == false
        and #inv.awards == 0 and rollCount == beforeRoll)

    -- Same sprite and index do not make a replacement object the paid machine.
    newScene()
    SandboxVars.ProjectArcade.CurrencyFullType = "Base.SilverCoin"
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "replace")
    completePaid(player, payment, "replace")
    local replacement = { square = world.square, spriteName = "pa_recreational_2" }
    function replacement:getSquare() return self.square end
    function replacement:getSprite()
        return { getName = function() return self.spriteName end }
    end
    world.square.objects[1] = replacement
    beforeRoll = rollCount
    check("exact_machine_required", prize(player, "replaced", payment.attemptId).ok == false
        and #inv.awards == 0 and rollCount == beforeRoll)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "move")
    completePaid(player, payment, "move")
    player.square = { tag = "away" }
    beforeRoll = rollCount
    check("front_required_redemption", prize(player, "away-roll", payment.attemptId).ok == false
        and rollCount == beforeRoll)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "sprite-change")
    completePaid(player, payment, "sprite_change")
    world.machine.spriteName = "pa_recreational_3"
    beforeRoll = rollCount
    check("sprite_required_redemption", prize(player, "sprite-roll", payment.attemptId).ok == false
        and rollCount == beforeRoll)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "power-change")
    completePaid(player, payment, "power_change")
    world.square.powered = false
    beforeRoll = rollCount
    check("power_required_redemption", prize(player, "power-roll", payment.attemptId).ok == false
        and rollCount == beforeRoll)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 2)
    payment = pay(player, "expiry")
    completePaid(player, payment, "expiry")
    now = now + 120001
    beforeRoll = rollCount
    check("expired_attempt_refused", prize(player, "late", payment.attemptId).ok == false
        and rollCount == beforeRoll)
    check("expired_nonce_not_recharged", pay(player, "expiry").ok == false
        and #inv.items == 1)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "failed-add")
    completePaid(player, payment, "failed_add")
    inv.failAdd = true
    beforeRoll = rollCount
    check("failed_add_not_ok", prize(player, "failed-add-roll", payment.attemptId).ok == false
        and #inv.awards == 0 and rollCount == beforeRoll + 1)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "no-prize")
    completePaid(player, payment, "no_prize")
    nextPrize = nil
    beforeRoll = rollCount
    check("no_prize_not_ok", prize(player, "no-prize-roll", payment.attemptId).ok == false
        and #inv.awards == 0 and rollCount == beforeRoll + 1)
    nextPrize = "Base.Spiffo"

    newScene()
    SandboxVars.ProjectArcade.CurrencyFullType = "Base.InvalidCoin"
    player, inv = newPlayer("Base.SilverCoin", 1)
    payment = pay(player, "fallback")
    check("invalid_currency_fallback", payment.ok == true
        and payment.currencyFullType == "Base.SilverCoin" and #inv.items == 0)
    completePaid(player, payment, "fallback")
    prize(player, "fallback-roll", payment.attemptId)

    newScene()
    SandboxVars.ProjectArcade.CurrencyFullType = "Base.GoldCoin"
    player, inv = newPlayer("Base.GoldCoin", 2)
    local shared = command("PayCoins", player,
        { nonce = "shared", cost = 0, currencyFullType = "Base.SilverCoin" })
    check("shared_payment_server_terms", shared.ok == true and #inv.items == 1)
    shared = command("PayCoins", player, { nonce = "shared-two", cost = 1000 })
    check("shared_client_cost_ignored", shared.ok == true and #inv.items == 0)

    newScene()
    player, inv = newPlayer("Base.SilverCoin", 1)
    local pusher = command("CoinPusherPlay", player,
        { x = 10, y = 20, z = 0, spriteName = "pa_recreational_2",
            pitId = 1, cost = 0 })
    check("pusher_server_cost", pusher.ok == true and #inv.items == 0)
    print("PASS claw MP server " .. tostring(checks) .. " checks")
    return checks
end
