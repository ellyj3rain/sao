if not isServer() then return end

require "ComputerMod_Mail"
require "ComputerMod_AccountRecovery"
require "ComputerMod_AccountSessions"
require "ComputerMod_ServerPlayers"

ComputerModMailServer = ComputerModMailServer or {}

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

function ComputerModMailServer.sendSync(player)
    if player and sendServerCommand then
        sendServerCommand(player, "ComputerModMail", "Sync", {store = ComputerModAccountSessions.publicCopy(ComputerModMail.getStore())})
    end
end

function ComputerModMailServer.broadcastSync()
    local players = ComputerModServerPlayers.get()
    if not players then return end
    for i = 0, players:size() - 1 do
        ComputerModMailServer.sendSync(players:get(i))
    end
end

function ComputerModMailServer.broadcast(command, args)
    if not sendServerCommand then return end
    local players = ComputerModServerPlayers.get()
    if not players then return end
    for i = 0, players:size() - 1 do
        sendServerCommand(players:get(i), "ComputerModMail", command, args or {})
    end
end

function ComputerModMailServer.sync(player)
    if player then
        ComputerModMailServer.sendSync(player)
    else
        ComputerModMailServer.broadcastSync()
    end
end

function ComputerModMailServer.reply(player, command, args)
    sendServerCommand(player, "ComputerModMail", command, args or {})
end

function ComputerModMailServer.onInitGlobalModData(isNewGame)
    ComputerModMail.getStore()
end

function ComputerModMailServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModMail" then return end
    if ComputerModServerPlayers and ComputerModServerPlayers.markReady then ComputerModServerPlayers.markReady() end
    args = args or {}

    if command == "RequestSync" then
        ComputerModMailServer.sync(player)
        return
    end

    if command == "EnsureAccount" then
        local success = false
        local reason = "invalid"
        local account = nil
        local created = false
        if args.address and args.address ~= "" then
            success, account, created = ComputerModMail.ensureAccount(args.address, args.password, args.messages)
            if success then
                local normalized = ComputerModMail.normalizeAddress(args.address)
                local payload = {address = normalized, account = ComputerModAccountSessions.publicCopy(account)}
                if created then
                    ComputerModMailServer.broadcast("AccountUpsert", payload)
                else
                    ComputerModMailServer.reply(player, "AccountUpsert", payload)
                end
                if args.authenticate == true then
                    local loginSuccess = ComputerModMail.login(normalized, args.password)
                    if loginSuccess then
                        ComputerModAccountSessions.authenticate("mail", player, normalized)
                    else
                        ComputerModAccountSessions.clear("mail", player)
                    end
                end
            else
                reason = account
            end
        end
        ComputerModMailServer.reply(player, "EnsureResult", {success = success == true, reason = success and "" or tostring(reason or "invalid"), address = tostring(args.address or "")})
        return
    end

    if command == "CreateAccount" then
        local success, result = ComputerModMail.createAccount(args.address, args.password)
        if success then
            local normalized = ComputerModMail.normalizeAddress(args.address)
            ComputerModAccountSessions.authenticate("mail", player, normalized)
            ComputerModMailServer.broadcast("AccountUpsert", {address = normalized, account = ComputerModAccountSessions.publicCopy(result)})
            ComputerModMailServer.reply(player, "CreateResult", {success = true, address = normalized})
        else
            ComputerModMailServer.reply(player, "CreateResult", {success = false, reason = tostring(result or "invalid")})
        end
        return
    end

    if command == "Login" then
        local success, result = ComputerModMail.login(args.address, args.password)
        if success then
            local normalized = ComputerModMail.normalizeAddress(args.address)
            ComputerModAccountSessions.authenticate("mail", player, normalized)
            ComputerModMailServer.reply(player, "LoginResult", {success = true, address = normalized})
        else
            ComputerModMailServer.reply(player, "LoginResult", {success = false, reason = tostring(result or "missing")})
        end
        return
    end

    if command == "Logout" then
        ComputerModAccountSessions.clear("mail", player)
        return
    end

    if command == "OpenRecoveryLink" then
        local address = ComputerModAccountSessions.resolve("mail", player, args.address, ComputerModMail.normalizeAddress)
        local account = address and ComputerModMail.getAccount(address) or nil
        local selected = nil
        if account and type(account.messages) == "table" then
            local messageId = tonumber(args.messageId or 0) or 0
            for i = 1, #account.messages do
                if tonumber(account.messages[i].id or 0) == messageId then
                    selected = account.messages[i]
                    break
                end
            end
        end
        if not selected or not selected.recoveryRequestId or (selected.recoveryService ~= "chat" and selected.recoveryService ~= "market") then
            ComputerModMailServer.reply(player, "RecoveryLinkResult", {success = false, reason = address and "expired" or "auth"})
            return
        end
        local success, request = ComputerModAccountRecovery.authorize(player, selected.recoveryRequestId, address)
        if success then
            ComputerModMailServer.reply(player, "RecoveryLinkResult", {
                success = true,
                service = request.service,
                username = request.username,
                requestId = request.id
            })
        else
            ComputerModMailServer.reply(player, "RecoveryLinkResult", {success = false, reason = tostring(request or "expired")})
        end
        return
    end

    if command == "SendMessage" then
        local fromAddress = ComputerModAccountSessions.resolve("mail", player, args.fromAddress, ComputerModMail.normalizeAddress)
        if not fromAddress then
            ComputerModMailServer.reply(player, "SendResult", {success = false, reason = "auth"})
            return
        end
        local success, result = ComputerModMail.sendMessage(fromAddress, args.toAddress, args.subject, args.body)
        if success then
            ComputerModMailServer.broadcast("MessageAdded", {address = ComputerModMail.normalizeAddress(args.toAddress), message = copyValue(result)})
            ComputerModMailServer.reply(player, "SendResult", {success = true, toAddress = ComputerModMail.normalizeAddress(args.toAddress)})
        else
            ComputerModMailServer.reply(player, "SendResult", {success = false, reason = tostring(result or "unknown")})
        end
        return
    end

    if command == "DeleteMessage" then
        local address = ComputerModAccountSessions.resolve("mail", player, args.address, ComputerModMail.normalizeAddress)
        if not address then
            ComputerModMailServer.reply(player, "DeleteResult", {success = false, reason = "auth", messageId = tonumber(args.messageId or 0) or 0})
            return
        end
        local success = ComputerModMail.deleteMessage(address, args.messageId)
        if success then
            ComputerModMailServer.broadcast("MessageDeleted", {address = address, messageId = tonumber(args.messageId or 0) or 0})
        end
        ComputerModMailServer.reply(player, "DeleteResult", {success = success == true, messageId = tonumber(args.messageId or 0) or 0})
        return
    end
end

Events.OnInitGlobalModData.Add(ComputerModMailServer.onInitGlobalModData)
Events.OnClientCommand.Add(ComputerModMailServer.onClientCommand)
