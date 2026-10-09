-- Integrated source: ProjectArcade; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ProjectArcade") then return end
require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

ProjectArcade_Currency = ProjectArcade_Currency or {}
ProjectArcade_Currency.PendingPays = ProjectArcade_Currency.PendingPays or {}
-- Only the source currency success path can mint a paid receipt. The private
-- registry prevents callers from manufacturing, replaying or retargeting one.
local paidReceipts = setmetatable({}, {__mode="k"})
local function mintReceipt(payment)
    local token = {}
    paidReceipts[token] = {character=payment.character, cost=payment.cost,
        currencyType=payment.currencyFullType, freePlay=payment.debugFreePlay == true,
        expectedMachine=payment.machine, serverAttemptId=payment.serverAttemptId}
    return token
end
local function matches(row, character, cost, currencyType, freePlay)
    return row and row.character == character and row.cost == cost
        and row.currencyType == currencyType and row.freePlay == (freePlay == true)
end
function ProjectArcade_Currency.bindPaidReceipt(token, character, machine, cost, currencyType, freePlay)
    local row = paidReceipts[token]
    if not machine or not matches(row, character, cost, currencyType, freePlay)
        or row.expectedMachine and row.expectedMachine ~= machine
        or row.machine then return false end
    row.machine = machine
    return true
end
function ProjectArcade_Currency.consumePaidReceipt(token, character, machine, cost, currencyType, freePlay)
    local row = paidReceipts[token]
    if not matches(row, character, cost, currencyType, freePlay)
        or row.machine ~= machine then return false end
    paidReceipts[token] = nil
    return true, row.serverAttemptId
end

local function safeGetText(key, ...)
    if getText then
        local ok, txt = pcall(getText, key, ...)
        if ok and txt and txt ~= key then return txt end
    end
    return key
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

ProjectArcade_Currency.Config = {
    Cost = 1,
    CurrencyFullType = "Base.SilverCoin",
    DebugFreePlay = false,
    NoCoinText = "ContextMenu_ProjectArcade_NotEnoughCoins",
}

-- =========================
-- Sandbox config
-- =========================
function ProjectArcade_Currency.ApplySandboxConfig()
    local ft = SandboxVars and SandboxVars.ProjectArcade and SandboxVars.ProjectArcade.CurrencyFullType
    if type(ft) == "string" then
        ft = ft:gsub("^%s+", ""):gsub("%s+$", "")
        if ft ~= "" then
            local sm = getScriptManager and getScriptManager()
            if sm and sm.FindItem and sm:FindItem(ft) then
                ProjectArcade_Currency.Config.CurrencyFullType = ft
            else
                print("[ProjectArcade] WARNING: Invalid CurrencyFullType in sandbox: " .. tostring(ft) .. " (fallback to Base.SilverCoin)")
                ProjectArcade_Currency.Config.CurrencyFullType = "Base.SilverCoin"
            end
        end
    end
end

local function PA_Currency_ApplySandboxOnStart()
    pcall(ProjectArcade_Currency.ApplySandboxConfig)
end

Events.OnGameStart.Add(PA_Currency_ApplySandboxOnStart)



ProjectArcade_Currency.CheckAndQueueAction = ISBaseTimedAction:derive("ProjectArcade_Currency_CheckAndQueueAction")

function ProjectArcade_Currency.CheckAndQueueAction:isValid()
    return true
end

function ProjectArcade_Currency.CheckAndQueueAction:perform()
    -- A machine selected by the menu can change before this queued action
    -- executes. Refuse before the source currency removal in that case.
    if self.prepayValid then
        local ok, valid = pcall(self.prepayValid)
        if not ok or valid ~= true then
            ISBaseTimedAction.perform(self)
            return
        end
    end
    -- FreePlay: no cobramos nada, encolamos directo.
    if self.debugFreePlay then
        if self.queueFn then self.queueFn(mintReceipt(self)) end
        ISBaseTimedAction.perform(self)
        return
    end

    -- MP CLIENT: el server cobra y responde. Acá solo pedimos el cobro.
    if isClient() and not isServer() then
        local machine = self.machine
        local square = machine and machine:getSquare() or nil
        local index = machine and machine:getObjectIndex() or nil
        if machine and (not square or type(index) ~= "number" or index < 0) then
            ISBaseTimedAction.perform(self)
            return
        end
        local nonce = tostring((getTimestampMs and getTimestampMs()) or 0) .. "-" .. tostring(ZombRand(1000000))

        ProjectArcade_Currency.PendingPays[nonce] = {
            character = self.character,
            cost = self.cost,
            currencyFullType = self.currencyFullType,
            noCoinText = self.noCoinText,
            queueFn = self.queueFn,
            debugFreePlay = false,
            machine = machine,
        }

        local request = { nonce = nonce }
        if machine then
            request.x, request.y, request.z = square:getX(), square:getY(), square:getZ()
            request.index = index
        else
            request.cost = self.cost
            request.currencyFullType = self.currencyFullType
        end
        sendClientCommand(self.character, "ProjectArcade",
            machine and "PayClawCoins" or "PayCoins", request)

        ISBaseTimedAction.perform(self)
        return
    end

    -- SP / Host / Server: cobramos local (está bien porque acá sí es autoridad)
    local inv = self.character and self.character:getInventory()
    local have = inv and inv:getCountTypeRecurse(self.currencyFullType) >= self.cost

    if have then
        for i = 1, self.cost do
            local c, coin = findItemRecursive(inv, self.currencyFullType)
            if not coin then
                have = false
                break
            end
            c:Remove(coin)
            if isServer() then
                sendRemoveItemFromContainer(c, coin)
            end
        end
    end

    if have then
        if self.queueFn then self.queueFn(mintReceipt(self)) end
    else
        if self.character and self.character.Say then
            local k = self.noCoinText or ProjectArcade_Currency.Config.NoCoinText
            self.character:Say(safeGetText(k))
        end
    end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_Currency.CheckAndQueueAction:new(character, cost, currencyFullType, debugFreePlay, noCoinText, queueFn, prepayValid, machine)
    local o = ISBaseTimedAction.new(self, character)
    o.stopOnWalk = false
    o.stopOnRun = false
    o.maxTime = 0
    o.useProgressBar = false

    o.cost = cost or ProjectArcade_Currency.Config.Cost
    o.currencyFullType = currencyFullType or ProjectArcade_Currency.Config.CurrencyFullType
    o.debugFreePlay = (debugFreePlay == true)
    o.noCoinText = noCoinText or ProjectArcade_Currency.Config.NoCoinText
    o.queueFn = queueFn
    o.prepayValid = prepayValid
    o.machine = machine

    return o
end

local function onServerCommand(module, command, args)
    if module ~= "ProjectArcade" then return end
    if command ~= "PayCoinsResult" and command ~= "PayClawCoinsResult" then return end

    local nonce = args and args.nonce
    if not nonce then return end

    local pending = ProjectArcade_Currency.PendingPays and ProjectArcade_Currency.PendingPays[nonce]
    if not pending then return end
    local claw = pending.machine ~= nil
    if (command == "PayClawCoinsResult") ~= claw then return end

    ProjectArcade_Currency.PendingPays[nonce] = nil

    local character = pending.character
    if not character then return end

    local accepted = args and args.ok == true
    if claw then
        accepted = accepted and type(args.attemptId) == "string"
            and args.attemptId ~= "" and type(args.cost) == "number"
            and args.cost >= 1 and args.cost == math.floor(args.cost)
            and args.cost <= 100 and type(args.currencyFullType) == "string"
            and args.currencyFullType ~= ""
        if accepted then
            pending.serverAttemptId = args.attemptId
            pending.cost = args.cost
            pending.currencyFullType = args.currencyFullType
        end
    end
    if accepted then
        if pending.queueFn then
            pending.queueFn(mintReceipt(pending), pending.cost,
                pending.currencyFullType, pending.serverAttemptId)
        end
    else
        if character and character.Say then
            local k = pending.noCoinText or ProjectArcade_Currency.Config.NoCoinText
            character:Say(safeGetText(k))
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)
