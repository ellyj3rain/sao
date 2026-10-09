-- Controlled Kahlua host for the real ProjectArcade menu, payment, and action Lua.
require = function() return nil end
SAO = { SourceIntegration = { active = function(id) return id == "ProjectArcade" end } }
local menuCallback
Events = {
    OnGameStart = { Add = function() end },
    OnServerCommand = { Add = function() end },
    OnPreFillWorldObjectContextMenu = { Add = function(fn) menuCallback = fn end },
}
SandboxVars = { ElecShutModifier = -1 }
local nights = 1
GameTime = { getInstance = function() return { getNightsSurvived = function() return nights end } end }
getText = function(key) return key end
getTexture = function(name) return "texture:" .. name end
isClient = function() return false end
isServer = function() return false end
ISLogSystem = { logAction = function() end }
Metabolics = { UsingTools = "UsingTools" }
GameSounds = { getSound = function() return nil end }
HaloTextHelper = { addTextWithArrow = function() end }

local queue = {}
ISTimedActionQueue = {
    add = function(action) queue[#queue + 1] = action end,
    getTimedActionQueue = function()
        return { onCompleted = function() end, resetQueue = function() end }
    end,
}
ISWalkToTimedAction = {
    new = function(_, character, front)
        return { Type = "ISWalkToTimedAction", character = character, front = front }
    end,
}

local player
getSpecificPlayer = function(index) if index == 0 then return player end end

local function newPlayer(coinCount)
    local coins = {}
    for i = 1, coinCount do
        coins[i] = { getFullType = function() return "Base.SilverCoin" end }
    end
    local inventory = {
        getCountTypeRecurse = function() return #coins end,
        getItems = function()
            return { size = function() return #coins end,
                get = function(_, index) return coins[index + 1] end }
        end,
        Remove = function(_, item)
            for i, found in ipairs(coins) do
                if found == item then table.remove(coins, i); return end
            end
            error("coin removal missed selected item")
        end,
    }
    local body = {
        Say = function(self, message) self.spoken = message end,
        isDead = function(self) return self.dead == true end,
        getSquare = function(self) return self.square end,
        getInventory = function() return inventory end,
        setIsFarming = function() end,
        setMetabolicTarget = function() end,
    }
    player = body
    return body, coins
end

local checks = 0
local function check(name, value)
    if not value then error("CLAW_MENU:" .. name) end
    checks = checks + 1
    print("CHECK " .. name)
end
local function menu(objects)
    local context = { options = {} }
    function context:addOption(label, suppliedObjects, callback)
        local option = { label = label, objects = suppliedObjects, callback = callback }
        self.options[#self.options + 1] = option
        return option
    end
    menuCallback(0, context, objects)
    return context.options
end
local function click(option) option.callback() end
local function resetQueue() for i = #queue, 1, -1 do queue[i] = nil end end

function __runClawMenuCases()
    check("menu_registered", type(menuCallback) == "function")
    check("actual_action_class_loaded", ProjectArcade_ClawTimedAction.Type == "ProjectArcade_ClawTimedAction")
    check("actual_payment_class_loaded", ProjectArcade_Currency.CheckAndQueueAction.Type ==
        "ProjectArcade_Currency_CheckAndQueueAction")

    local wrong = __newMachine("pa_recreational_6", true)
    check("native_userdata_receiver", type(wrong) == "userdata")
    check("wrong_sprite_rejected", ProjectArcade_ClawMachine.isMachine(wrong) == false)
    newPlayer(2)
    check("wrong_sprite_no_menu", #menu({ wrong }) == 0)

    local grouped = __newMachine("custom_pa_recreational_2_repaint", true,
        "arcade_clawmachine")
    local groupedProps = grouped:getSprite():getProperties()
    check("native_userdata_properties", type(groupedProps) == "userdata")
    check("native_group_has_get", groupedProps:has("GroupName")
        and groupedProps:get("GroupName") == "arcade_clawmachine")
    check("grouped_sprite_admitted", ProjectArcade_ClawMachine.isMachine(grouped))
    check("grouped_sprite_front", ProjectArcade_ClawMachine.front(grouped)
        == grouped:getSquare():getS())
    check("grouped_sprite_menu", #menu({ grouped }) == 1)
    local ungrouped = __newMachine("custom_pa_recreational_2_repaint", true,
        "other_group")
    check("other_group_rejected", not ProjectArcade_ClawMachine.isMachine(ungrouped)
        and #menu({ ungrouped }) == 0)
    local noOrientation = __newMachine("unoriented_repaint", true,
        "arcade_clawmachine")
    check("group_without_orientation_no_menu",
        not ProjectArcade_ClawMachine.isMachine(noOrientation)
        and ProjectArcade_ClawMachine.front(noOrientation) == nil
        and #menu({ noOrientation }) == 0)
    local ambiguous = __newMachine(
        "custom_pa_recreational_2_pa_recreational_3", true,
        "arcade_clawmachine")
    check("group_with_two_orientations_no_menu",
        not ProjectArcade_ClawMachine.isMachine(ambiguous)
        and #menu({ ambiguous }) == 0)

    local powered = __newMachine("pa_recreational_2", false)
    check("power_reader_unpowered_refused", ProjectArcade_ClawMachine.power(powered) == false)
    SandboxVars.ElecShutModifier = 5
    check("pre_shutoff_power_read", ProjectArcade_ClawMachine.power(powered) == true)
    SandboxVars.ElecShutModifier = 0
    check("at_shutoff_power_refused", ProjectArcade_ClawMachine.power(powered) == false)
    __setPower(powered, true)
    check("square_electricity_read", ProjectArcade_ClawMachine.power(powered) == true)
    SandboxVars.ElecShutModifier = -1

    ProjectArcade_Currency.Config.Cost = 2
    ProjectArcade_Currency.Config.CurrencyFullType = "Base.SilverCoin"
    ProjectArcade_Currency.Config.DebugFreePlay = false
    resetQueue()
    local groupedBody, groupedCoins = newPlayer(2)
    click(menu({ grouped })[1])
    check("grouped_menu_walk_front", #queue == 2
        and queue[1].front == grouped:getSquare():getS())
    groupedBody.square = grouped:getSquare():getS()
    queue[2]:perform()
    check("grouped_sprite_pays_and_queues_action", #groupedCoins == 0
        and queue[3] and queue[3].machine == grouped)

    for _, row in ipairs({
        { sprite = "pa_recreational_2", direction = "S" },
        { sprite = "pa_recreational_3", direction = "E" },
        { sprite = "pa_recreational_4", direction = "N" },
        { sprite = "pa_recreational_5", direction = "W" },
    }) do
        local machine = __newMachine(row.sprite, true)
        local other = __newMachine(row.sprite, true)
        local square = machine:getSquare()
        local front = square["get" .. row.direction](square)
        check(row.direction .. "_sprite_admitted", ProjectArcade_ClawMachine.isMachine(machine))
        check(row.direction .. "_front_exact", ProjectArcade_ClawMachine.front(machine) == front)
        for _, alternate in ipairs({ "S", "E", "N", "W" }) do
            if alternate ~= row.direction then
                check(row.direction .. "_front_not_" .. alternate,
                    ProjectArcade_ClawMachine.front(machine) ~= square["get" .. alternate](square))
            end
        end
        resetQueue()
        local body, coins = newPlayer(2)
        local options = menu({ wrong, machine })
        check(row.direction .. "_one_option", #options == 1 and
            options[1].label == "ContextMenu_ProjectArcade_PlayClawMachine")
        check(row.direction .. "_south_icon", options[1].iconTexture == "texture:pa_recreational_2")
        click(options[1])
        check(row.direction .. "_walk_front", #queue == 2 and queue[1].front == front and
            queue[1].character == body)
        body.square = front
        local payment = queue[2]
        check(row.direction .. "_source_payment_queued", payment.Type ==
            "ProjectArcade_Currency_CheckAndQueueAction" and payment.cost == 2 and
            payment.currencyFullType == "Base.SilverCoin")
        payment:perform()
        check(row.direction .. "_exact_debit", #coins == 0)
        local action = queue[3]
        check(row.direction .. "_actual_action_ctor", action and
            action.Type == "ProjectArcade_ClawTimedAction" and action.character == body and
            action.machine == machine and action.cost == 2 and action.paidReceipt ~= nil)
        check(row.direction .. "_cannot_rebind_other_machine",
            not ProjectArcade_Currency.bindPaidReceipt(action.paidReceipt, body, other,
                2, "Base.SilverCoin", false))
        local wrongAction = ProjectArcade_ClawTimedAction:new(body, other,
            2, "Base.SilverCoin", false, nil)
        wrongAction.paidReceipt = action.paidReceipt
        wrongAction:start()
        check(row.direction .. "_wrong_machine_unpaid", wrongAction.paid == false)
        action.action = { setActionAnim = function() end }
        action:start()
        check(row.direction .. "_bound_machine_paid", action.paid == true)
        local replay = ProjectArcade_ClawTimedAction:new(body, machine,
            2, "Base.SilverCoin", false, nil)
        replay.paidReceipt = action.paidReceipt
        replay:start()
        check(row.direction .. "_receipt_single_use", replay.paid == false)
    end

    resetQueue()
    local body, coins = newPlayer(2)
    local blocked = __newMachine("pa_recreational_2", true)
    local blockedOption = menu({ blocked })[1]
    check("powered_menu_offered", blockedOption ~= nil)
    __setPower(blocked, false)
    click(blockedOption)
    check("click_power_revalidated", #queue == 0 and #coins == 2 and
        body.spoken == "ContextMenu_ProjectArcade_NeedPower")

    resetQueue()
    body, coins = newPlayer(2)
    local replaced = __newMachine("pa_recreational_2", true)
    local staleOption = menu({ replaced })[1]
    check("admitted_sprite_menu_offered", staleOption ~= nil)
    __setSprite(replaced, "pa_recreational_6")
    check("replaced_sprite_no_longer_machine", not ProjectArcade_ClawMachine.isMachine(replaced))
    click(staleOption)
    check("click_sprite_revalidated_before_charge", #queue == 0 and #coins == 2)

    resetQueue()
    body, coins = newPlayer(2)
    local rotated = __newMachine("pa_recreational_2", true)
    click(menu({ rotated })[1])
    body.square = rotated:getSquare():getS()
    check("rotation_payment_waiting", #queue == 2 and #coins == 2)
    __setSprite(rotated, "pa_recreational_3")
    queue[2]:perform()
    check("rotation_before_debit_refused", #queue == 2 and #coins == 2)

    resetQueue()
    body, coins = newPlayer(2)
    local removed = __newMachine("pa_recreational_2", true)
    click(menu({ removed })[1])
    body.square = removed:getSquare():getS()
    check("removed_payment_waiting", #queue == 2 and #coins == 2)
    __removeSquare(removed)
    queue[2]:perform()
    check("removed_before_debit_refused", #queue == 2 and #coins == 2)

    resetQueue()
    body, coins = newPlayer(2)
    local dark = __newMachine("pa_recreational_2", true)
    click(menu({ dark })[1])
    body.square = dark:getSquare():getS()
    check("dark_payment_waiting", #queue == 2 and #coins == 2)
    __setPower(dark, false)
    queue[2]:perform()
    check("dark_before_debit_refused", #queue == 2 and #coins == 2)

    resetQueue()
    body, coins = newPlayer(2)
    local distant = __newMachine("pa_recreational_2", true)
    click(menu({ distant })[1])
    check("distant_payment_waiting", #queue == 2 and #coins == 2)
    body.square = distant:getSquare():getE()
    queue[2]:perform()
    check("player_left_front_before_debit_refused", #queue == 2 and #coins == 2)

    resetQueue()
    body, coins = newPlayer(2)
    local actionMachine = __newMachine("pa_recreational_2", true)
    click(menu({ actionMachine })[1])
    body.square = actionMachine:getSquare():getS()
    queue[2]:perform()
    local pendingAction = queue[3]
    check("valid_action_queued", pendingAction and pendingAction:isValid())
    body.square = actionMachine:getSquare():getE()
    check("player_left_front_action_invalid", not pendingAction:isValid())
    body.square = actionMachine:getSquare():getS()
    check("returned_to_front_action_valid", pendingAction:isValid())
    __setSprite(actionMachine, "pa_recreational_3")
    check("rotated_action_invalid", not pendingAction:isValid())
    __setSprite(actionMachine, "pa_recreational_6")
    check("nonclaw_action_invalid", not pendingAction:isValid())
    __removeSquare(actionMachine)
    check("removed_action_invalid", not pendingAction:isValid())

    resetQueue()
    body, coins = newPlayer(1)
    local short = __newMachine("pa_recreational_3", true)
    click(menu({ short })[1])
    body.square = short:getSquare():getE()
    check("insufficient_currency_queues_payment", #queue == 2)
    queue[2]:perform()
    check("insufficient_currency_no_action", #queue == 2 and #coins == 1 and
        body.spoken == "ContextMenu_ProjectArcade_NotEnoughCoins")

    body = newPlayer(2)
    body.dead = true
    check("dead_player_no_menu", #menu({ short }) == 0)
    return "PASS claw menu " .. checks
end
