if not isServer() then return end

require "ComputerMod_Market"
require "ComputerMod_Mail"
require "ComputerMod_AccountRecovery"
require "ComputerMod_Debug"
require "ComputerMod_AccountSessions"
require "ComputerMod_ServerPlayers"

ComputerModMarketServer = ComputerModMarketServer or {}

function ComputerModMarketServer.sendSync(player)
    if player and sendServerCommand then
        local username = ComputerModAccountSessions.get("market", player)
        if username and ComputerModMarket.prepareJobProgress then
            ComputerModMarket.prepareJobProgress(username, ComputerModMarket.getPlayerZombieKills(player))
        end
        sendServerCommand(player, "ComputerModMarket", "Sync", {store = ComputerModAccountSessions.publicCopy(ComputerModMarket.getStore())})
    end
end

function ComputerModMarketServer.broadcastSync()
    local players = ComputerModServerPlayers.get()
    if not players then return end
    for i = 0, players:size() - 1 do
        ComputerModMarketServer.sendSync(players:get(i))
    end
end

function ComputerModMarketServer.sync(player)
    if player then
        ComputerModMarketServer.sendSync(player)
    else
        ComputerModMarketServer.broadcastSync()
    end
end

function ComputerModMarketServer.reply(player, command, args)
    sendServerCommand(player, "ComputerModMarket", command, args or {})
end

local function copyValue(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for k, v in pairs(value) do
        copy[copyValue(k, seen)] = copyValue(v, seen)
    end
    return copy
end

local function sendRecoveryMessage(username, recoveryEmail)
    local success, request = ComputerModAccountRecovery.request("market", username, recoveryEmail)
    if not success then return false end
    local sent, message = ComputerModMail.sendMessage(
        "security@knoxnet.local",
        recoveryEmail,
        "KnoxMarket password reset",
        "A password reset was requested for KnoxMarket account " .. username .. ". Open this message and select Open reset link to choose a new password."
    )
    if not sent then return false end
    message.recoveryService = "market"
    message.recoveryRequestId = request.id
    message.recoveryUsername = username
    local players = sendServerCommand and ComputerModServerPlayers.get() or nil
    if players then
        for i = 0, players:size() - 1 do
            sendServerCommand(players:get(i), "ComputerModMail", "MessageAdded", {
                address = recoveryEmail,
                message = copyValue(message)
            })
        end
    end
    return true
end

function ComputerModMarketServer.giveItem(player, fullType)
    if not player or not player.getInventory or not fullType then return false end
    local inventory = player:getInventory()
    if not inventory or not inventory.AddItem then return false end
    local item = nil

    -- Vanilla B42 server code creates inventory items through instanceItem().
    -- InventoryItemFactory is not consistently exposed on dedicated servers,
    -- which made every otherwise-valid purchase roll back as "item".
    if instanceItem then
        local okInstance, created = pcall(function() return instanceItem(fullType) end)
        if okInstance then item = created end
    end
    if not item and InventoryItemFactory and InventoryItemFactory.CreateItem then
        local okCreate, created = pcall(function() return InventoryItemFactory.CreateItem(fullType) end)
        if okCreate then item = created end
    end
    -- Avoid B42's unsafe string overload; an unavailable script item should
    -- fail the purchase cleanly instead of raising a Java NPE.
    if not item then return false end
    local ok = pcall(function() inventory:AddItem(item) end)
    if ok and item and sendAddItemToContainer then
        local syncOk = pcall(function() sendAddItemToContainer(inventory, item) end)
        if not syncOk then
            pcall(function() inventory:Remove(item) end)
            return false
        end
    end
    return ok == true and item ~= nil
end

function ComputerModMarketServer.onInitGlobalModData(isNewGame)
    ComputerModMarket.getStore()
end

function ComputerModMarketServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModMarket" then return end
    if ComputerModServerPlayers and ComputerModServerPlayers.markReady then ComputerModServerPlayers.markReady() end
    args = args or {}

    if command == "RequestSync" then
        ComputerModMarketServer.sync(player)
        return
    end

    if command == "CreateAccount" then
        local recoveryEmail = ComputerModMail.normalizeAddress(args.recoveryEmail or "")
        if recoveryEmail == "" then
            recoveryEmail = ComputerModAccountSessions.get("mail", player) or ""
        end
        local success, result = ComputerModMarket.createAccount(args.username, args.password, recoveryEmail)
        if success then
            local normalized = ComputerModMarket.normalizeUsername(args.username)
            ComputerModAccountSessions.authenticate("market", player, normalized)
            ComputerModMarketServer.sync()
            ComputerModMarketServer.reply(player, "CreateResult", {success = true, username = normalized})
        else
            ComputerModMarketServer.reply(player, "CreateResult", {success = false, reason = tostring(result or "invalid")})
        end
        return
    end

    if command == "Login" then
        local success, result = ComputerModMarket.login(args.username, args.password)
        if success then
            local normalized = ComputerModMarket.normalizeUsername(args.username)
            ComputerModAccountSessions.authenticate("market", player, normalized)
            ComputerModMarketServer.sync()
            ComputerModMarketServer.reply(player, "LoginResult", {success = true, username = normalized})
        else
            ComputerModMarketServer.reply(player, "LoginResult", {success = false, reason = tostring(result or "missing")})
        end
        return
    end

    if command == "Logout" then
        ComputerModAccountSessions.clear("market", player)
        return
    end

    if command == "RequestPasswordReset" then
        local username = ComputerModMarket.normalizeUsername(args.username)
        local account = ComputerModMarket.getAccount(username)
        local success = account and account.recoveryEmail and ComputerModMail.getAccount(account.recoveryEmail) and sendRecoveryMessage(username, account.recoveryEmail) or false
        ComputerModMarketServer.reply(player, "RecoveryRequestResult", {success = success == true})
        return
    end

    if command == "ResetPassword" then
        local password = ComputerModMarket.trim(args.password or "")
        if password == "" then
            ComputerModMarketServer.reply(player, "PasswordResetResult", {success = false, reason = "password"})
            return
        end
        local authorized, username = ComputerModAccountRecovery.consume(player, args.requestId, "market")
        local account = authorized and ComputerModMarket.getAccount(username) or nil
        if not account then
            ComputerModMarketServer.reply(player, "PasswordResetResult", {success = false, reason = tostring(username or "expired")})
            return
        end
        account.password = password
        ComputerModAccountSessions.clearAccount("market", username)
        ComputerModAccountSessions.authenticate("market", player, username)
        ComputerModMarketServer.sync()
        ComputerModMarketServer.reply(player, "PasswordResetResult", {success = true, username = username})
        return
    end

    if command == "BuyItem" then
        local username = ComputerModAccountSessions.resolve("market", player, args.username, ComputerModMarket.normalizeUsername)
        if not username then
            ComputerModMarketServer.reply(player, "BuyResult", {success = false, reason = "auth", itemId = tostring(args.itemId or "")})
            return
        end
        local valid, account, item = ComputerModMarket.validatePurchase(username, args.itemId)
        local success = false
        local reason = valid and "" or tostring(account or "missing")
        if valid and item then
            local applied, purchased = ComputerModMarket.applyPurchase(username, args.itemId)
            if applied and purchased then
                if ComputerModMarketServer.giveItem(player, purchased.fullType or item.fullType) then
                    success = true
                    ComputerModMarketServer.sync()
                else
                    account.money = (tonumber(account.money or 0) or 0) + (tonumber(purchased.price or item.price or 0) or 0)
                    purchased.stock = (tonumber(purchased.stock or 0) or 0) + 1
                    reason = "item"
                    ComputerModMarketServer.sync()
                end
            else
                reason = tostring(purchased or "missing")
            end
        end
        ComputerModMarketServer.reply(player, "BuyResult", {success = success == true, reason = success and "" or reason, itemId = tostring(args.itemId or "")})
        return
    end

    if command == "CompleteJob" then
        local username = ComputerModAccountSessions.resolve("market", player, args.username, ComputerModMarket.normalizeUsername)
        if not username then
            ComputerModMarketServer.reply(player, "JobResult", {success = false, reason = "auth", jobId = tostring(args.jobId or "")})
            return
        end
        local success, result = ComputerModMarket.completeJob(username, args.jobId, player, args.startKills, args.minigamePassed == true)
        if success then
            ComputerModMarketServer.sync()
        end
        ComputerModMarketServer.reply(player, "JobResult", {success = success == true, reason = success and "" or tostring(result or "missing"), jobId = tostring(args.jobId or "")})
        return
    end

    if command == "DebugMoney" then
        local username = ComputerModAccountSessions.resolve("market", player, args.username, ComputerModMarket.normalizeUsername)
        if not username then
            ComputerModMarketServer.reply(player, "DebugMoneyResult", {success = false, reason = "auth"})
            return
        end
        local success = false
        if ComputerModDebug.isEnabled(player) then
            success = ComputerModMarket.addDebugMoney(username, 1000)
            if success then
                ComputerModMarketServer.sync()
            end
        end
        ComputerModMarketServer.reply(player, "DebugMoneyResult", {success = success == true})
        return
    end

    if command == "ResetShop" or command == "ResetJobs" then
        local success = false
        if ComputerModDebug.isEnabled(player) then
            ComputerModMarket.resetDaily(command == "ResetJobs" and "jobs" or "shop")
            ComputerModMarketServer.sync()
            success = true
        end
        ComputerModMarketServer.reply(player, command .. "Result", {success = success == true})
        return
    end
end

Events.OnInitGlobalModData.Add(ComputerModMarketServer.onInitGlobalModData)
Events.OnClientCommand.Add(ComputerModMarketServer.onClientCommand)
