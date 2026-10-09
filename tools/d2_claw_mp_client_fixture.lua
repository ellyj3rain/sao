-- Controlled MP client receivers for the packaged ProjectArcade Lua.
require = function() return nil end
SAO = { SourceIntegration = { active = function(id) return id == "ProjectArcade" end } }
local menuCallback
local serverHandlers = {}
Events = {
    OnGameStart = { Add = function() end },
    OnServerCommand = { Add = function(fn) serverHandlers[#serverHandlers + 1] = fn end },
    OnPreFillWorldObjectContextMenu = { Add = function(fn) menuCallback = fn end },
}
SandboxVars = { ElecShutModifier = -1 }
GameTime = { getInstance = function() return { getNightsSurvived = function() return 1 end } end }
getText = function(key) return key end
getTexture = function(name) return "texture:" .. name end
isClient = function() return true end
isServer = function() return false end
getTimestampMs = function() return 1000 end
local randomCounter = 0
ZombRand = function() randomCounter = randomCounter + 1; return randomCounter end
ISLogSystem = { logAction = function() end }
Metabolics = { UsingTools = "UsingTools" }
GameSounds = { getSound = function() return nil end }
local halo = {}
HaloTextHelper = { addTextWithArrow = function(player, message)
    halo[#halo + 1] = { player = player, message = message }
end }

local queue = {}
ISTimedActionQueue = {
    add = function(action) queue[#queue + 1] = action end,
    getTimedActionQueue = function()
        return { onCompleted = function() end, resetQueue = function() end }
    end,
}
ISWalkToTimedAction = { new = function(_, character, front)
    return { Type = "ISWalkToTimedAction", character = character, front = front }
end }

local sent = {}
sendClientCommand = function(a, b, c, d)
    if d ~= nil then
        sent[#sent + 1] = { player = a, module = b, command = c, args = d }
    else
        sent[#sent + 1] = { module = a, command = b, args = c }
    end
end

local players = {}
getSpecificPlayer = function(index) return players[index] end

local function newPlayer(index)
    local inv = { coins = 2, removed = 0, added = 0 }
    function inv:getCountTypeRecurse() return self.coins end
    function inv:getItems()
        return { size = function() return self.coins end,
            get = function() return { getFullType = function() return "Base.SilverCoin" end } end }
    end
    function inv:Remove()
        self.removed = self.removed + 1
        self.coins = self.coins - 1
    end
    function inv:AddItem()
        self.added = self.added + 1
        error("MP client awarded an item locally")
    end
    local body = {
        Say = function(self, message) self.spoken = message end,
        isDead = function() return false end,
        getSquare = function(self) return self.square end,
        getInventory = function() return inv end,
        getPlayerNum = function() return index end,
        setIsFarming = function() end,
        setMetabolicTarget = function() end,
        isPlayerMoving = function() return false end,
        isTurning = function() return false end,
        shouldBeTurning = function() return false end,
    }
    players[index] = body
    return body, inv
end

local checks = 0
local function check(name, value)
    if not value then error("CLAW_MP:" .. name) end
    checks = checks + 1
    print("CHECK " .. name)
end

local function clear(list)
    for i = #list, 1, -1 do list[i] = nil end
end

local function menu(index, machine)
    local context = { options = {} }
    function context:addOption(label, _, callback)
        local option = { label = label, callback = callback }
        self.options[#self.options + 1] = option
        return option
    end
    menuCallback(index, context, { machine })
    return context.options
end

local function dispatch(module, command, args)
    for _, handler in ipairs(serverHandlers) do handler(module, command, args) end
end

local function commandNamed(name)
    for _, row in ipairs(sent) do
        if row.command == name then return row end
    end
    return nil
end

local function request(index, machine)
    clear(queue)
    clear(sent)
    local body, inv = newPlayer(index)
    local options = menu(index, machine)
    check("menu_offered", #options == 1)
    options[1].callback()
    check("menu_queued_walk_then_payment", #queue == 2
        and queue[1].Type == "ISWalkToTimedAction"
        and queue[2].Type == "ProjectArcade_Currency_CheckAndQueueAction")
    body.square = queue[1].front
    queue[2]:perform()
    return body, inv, commandNamed("PayClawCoins")
end

function __runClawMpClientCases()
    check("actual_menu_loaded", type(menuCallback) == "function")
    check("actual_currency_loaded", type(ProjectArcade_Currency.bindPaidReceipt) == "function")
    check("actual_action_loaded", ProjectArcade_ClawTimedAction.Type == "ProjectArcade_ClawTimedAction")
    check("payment_and_prize_handlers", #serverHandlers == 2)
    check("client_mode", isClient() and not isServer())
    ProjectArcade_Currency.Config.Cost = 2
    ProjectArcade_Currency.Config.CurrencyFullType = "Base.SilverCoin"
    ProjectArcade_Currency.Config.DebugFreePlay = false

    local machine = __newMachine("pa_recreational_2", true, 123, 456, 0, 7)
    local other = __newMachine("pa_recreational_2", true, 124, 456, 0, 8)
    local body, inv, pay = request(1, machine)
    check("native_machine_userdata", type(machine) == "userdata")
    check("no_local_debit", inv.coins == 2 and inv.removed == 0 and #queue == 2)
    local requestFields = 0
    if pay then for _ in pairs(pay.args) do requestFields = requestFields + 1 end end
    check("exact_pay_command", pay and pay.player == body and pay.module == "ProjectArcade"
        and pay.args.x == 123 and pay.args.y == 456 and pay.args.z == 0
        and pay.args.index == 7 and type(pay.args.nonce) == "string"
        and pay.args.cost == nil and pay.args.currencyFullType == nil
        and requestFields == 5)
    local nonce = pay.args.nonce
    check("payment_pending", ProjectArcade_Currency.PendingPays[nonce] ~= nil)

    dispatch("OtherModule", "PayClawCoinsResult", {
        nonce = nonce, ok = true, attemptId = "wrong-module", cost = 2,
        currencyFullType = "Base.SilverCoin" })
    dispatch("ProjectArcade", "PayCoinsResult", {
        nonce = nonce, ok = true, attemptId = "wrong-command", cost = 2,
        currencyFullType = "Base.SilverCoin" })
    dispatch("ProjectArcade", "PayClawCoinsResult", {
        nonce = "unknown", ok = true, attemptId = "unknown", cost = 2,
        currencyFullType = "Base.SilverCoin" })
    check("forged_ack_ignored", #queue == 2 and ProjectArcade_Currency.PendingPays[nonce] ~= nil)

    dispatch("ProjectArcade", "PayClawCoinsResult", {
        nonce = nonce, ok = true, cost = 2, currencyFullType = "Base.SilverCoin" })
    check("missing_attempt_refused", #queue == 2
        and ProjectArcade_Currency.PendingPays[nonce] == nil)

    body, inv, pay = request(1, machine)
    dispatch("ProjectArcade", "PayClawCoinsResult", {
        nonce = pay.args.nonce, ok = true, attemptId = "wrong-cost",
        cost = 0, currencyFullType = "Base.SilverCoin" })
    check("invalid_cost_refused", #queue == 2 and inv.removed == 0)

    body, inv, pay = request(1, machine)
    dispatch("ProjectArcade", "PayClawCoinsResult", {
        nonce = pay.args.nonce, ok = true, attemptId = "wrong-currency",
        cost = 2, currencyFullType = "" })
    check("invalid_currency_refused", #queue == 2 and inv.removed == 0)

    body, inv, pay = request(1, machine)
    nonce = pay.args.nonce
    dispatch("ProjectArcade", "PayClawCoinsResult", {
        nonce = nonce, ok = true, attemptId = "server-attempt-1",
        cost = 1, currencyFullType = "Base.SilverCoin" })
    local action = queue[3]
    check("matching_ack_queues_action", action and action.Type == "ProjectArcade_ClawTimedAction"
        and action.character == body and action.machine == machine and action.paidReceipt
        and action.cost == 1 and action.currencyFullType == "Base.SilverCoin"
        and action.serverAttemptId == "server-attempt-1")
    check("receipt_opaque", type(action.paidReceipt) == "table"
        and action.paidReceipt.character == nil and action.paidReceipt.attemptId == nil)
    check("matching_ack_no_client_debit", inv.coins == 2 and inv.removed == 0)
    check("ack_replay_ignored", ProjectArcade_Currency.PendingPays[nonce] == nil)
    dispatch("ProjectArcade", "PayClawCoinsResult", {
        nonce = nonce, ok = true, attemptId = "server-attempt-2",
        cost = 1, currencyFullType = "Base.SilverCoin" })
    check("ack_replay_no_second_action", #queue == 3)

    local forged = ProjectArcade_ClawTimedAction:new(body, machine,
        1, "Base.SilverCoin", false, "forged-attempt")
    forged.paidReceipt = {}
    forged:start()
    check("forged_receipt_refused", forged.paid == false)
    local cross = ProjectArcade_ClawTimedAction:new(body, other,
        1, "Base.SilverCoin", false, "server-attempt-1")
    cross.paidReceipt = action.paidReceipt
    cross:start()
    check("cross_machine_receipt_refused", cross.paid == false
        and not ProjectArcade_Currency.bindPaidReceipt(action.paidReceipt, body,
            other, 1, "Base.SilverCoin", false))

    action.action = { setActionAnim = function() end }
    action:start()
    check("authoritative_attempt_starts", action.paid == true
        and action.serverAttemptId == "server-attempt-1")
    check("native_client_completion_gate", action:complete() == true
        and forged:complete() == false)
    local replay = ProjectArcade_ClawTimedAction:new(body, machine,
        1, "Base.SilverCoin", false, "server-attempt-1")
    replay.paidReceipt = action.paidReceipt
    replay.action = { setActionAnim = function() end }
    replay:start()
    check("token_replay_refused", replay.paid == false)

    action:perform()
    local roll = commandNamed("RollPrize")
    check("roll_sends_same_attempt", roll and roll.player == body
        and roll.module == "ProjectArcade" and roll.args.attemptId == "server-attempt-1")
    check("roll_uses_separate_nonce", roll.args.nonce ~= nonce
        and type(roll.args.nonce) == "string")
    check("client_does_not_award", inv.added == 0 and action.saoPrizeResult.state == "server-pending")
    check("result_pending_player_one", ProjectArcade_PrizeNet.Pending[roll.args.nonce]
        and ProjectArcade_PrizeNet.Pending[roll.args.nonce].playerIndex == 1)
    local otherPlayer = newPlayer(0)
    dispatch("ProjectArcade", "RollPrizeResult", {
        nonce = "wrong-result", ok = true, displayName = "Wrong" })
    check("wrong_result_ignored", #halo == 0)
    dispatch("ProjectArcade", "RollPrizeResult", {
        nonce = roll.args.nonce, ok = true, displayName = "Prize One" })
    check("result_routed_to_player_one", #halo == 1 and halo[1].player == body
        and halo[1].player ~= otherPlayer and string.find(halo[1].message, "Prize One", 1, true))
    dispatch("ProjectArcade", "RollPrizeResult", {
        nonce = roll.args.nonce, ok = true, displayName = "Prize One" })
    check("result_replay_ignored", #halo == 1
        and ProjectArcade_PrizeNet.Pending[roll.args.nonce] == nil)

    ProjectArcade_Currency.Config.DebugFreePlay = true
    body, inv, pay = request(1, machine)
    check("debug_freeplay_sends_no_payment", pay == nil and #queue == 3 and inv.removed == 0)
    local debugAction = queue[3]
    debugAction.action = { setActionAnim = function() end }
    debugAction:start()
    check("debug_freeplay_without_attempt_refused", debugAction.paid == false)
    local directDebug = ProjectArcade_ClawTimedAction:new(body, machine,
        2, "Base.SilverCoin", true, nil)
    directDebug.action = { setActionAnim = function() end }
    directDebug:start()
    check("direct_debug_without_attempt_refused", directDebug.paid == false)
    ProjectArcade_Currency.Config.DebugFreePlay = false

    return "PASS claw MP client " .. checks
end
