require "TimedActions/ISBaseTimedAction"
require "TimedActions/ISTimedActionQueue"

ProjectArcade_Currency = ProjectArcade_Currency or {}
ProjectArcade_Currency.PendingPays = ProjectArcade_Currency.PendingPays or {}

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
        ft = ft:gsub("^\\s+", ""):gsub("\\s+$", "")
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
    -- FreePlay: no cobramos nada, encolamos directo.
    if self.debugFreePlay then
        if self.queueFn then self.queueFn() end
        ISBaseTimedAction.perform(self)
        return
    end

    -- MP CLIENT: el server cobra y responde. Acá solo pedimos el cobro.
    if isClient() and not isServer() then
        local nonce = tostring((getTimestampMs and getTimestampMs()) or 0) .. "-" .. tostring(ZombRand(1000000))

        ProjectArcade_Currency.PendingPays[nonce] = {
            character = self.character,
            cost = self.cost,
            currencyFullType = self.currencyFullType,
            noCoinText = self.noCoinText,
            queueFn = self.queueFn,
        }

        sendClientCommand(self.character, "ProjectArcade", "PayCoins", {
            nonce = nonce,
            cost = self.cost,
            currencyFullType = self.currencyFullType,
        })

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
        if self.queueFn then self.queueFn() end
    else
        if self.character and self.character.Say then
            local k = self.noCoinText or ProjectArcade_Currency.Config.NoCoinText
            self.character:Say(safeGetText(k))
        end
    end

    ISBaseTimedAction.perform(self)
end

function ProjectArcade_Currency.CheckAndQueueAction:new(character, cost, currencyFullType, debugFreePlay, noCoinText, queueFn)
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

    return o
end

local function onServerCommand(module, command, args)
    if module ~= "ProjectArcade" then return end
    if command ~= "PayCoinsResult" then return end

    local nonce = args and args.nonce
    if not nonce then return end

    local pending = ProjectArcade_Currency.PendingPays and ProjectArcade_Currency.PendingPays[nonce]
    if not pending then return end

    ProjectArcade_Currency.PendingPays[nonce] = nil

    local character = pending.character
    if not character then return end

    if args and args.ok == true then
        if pending.queueFn then
            pending.queueFn()
        end
    else
        if character and character.Say then
            local k = pending.noCoinText or ProjectArcade_Currency.Config.NoCoinText
            character:Say(safeGetText(k))
        end
    end
end

Events.OnServerCommand.Add(onServerCommand)
