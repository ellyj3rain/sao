if not isServer() then return end

require "ComputerMod_Chat"
require "ComputerMod_Mail"
require "ComputerMod_AccountRecovery"
require "ComputerMod_AccountSessions"
require "ComputerMod_ServerPlayers"

ComputerModChatServer = ComputerModChatServer or {}

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

function ComputerModChatServer.sendSync(player)
    if player and sendServerCommand then
        sendServerCommand(player, "ComputerModChat", "Sync", {store = ComputerModAccountSessions.publicCopy(ComputerModChat.getStore())})
    end
end

function ComputerModChatServer.broadcastSync()
    local players = ComputerModServerPlayers.get()
    if not players then return end
    for i = 0, players:size() - 1 do
        ComputerModChatServer.sendSync(players:get(i))
    end
end

function ComputerModChatServer.broadcast(command, args)
    if not sendServerCommand then return end
    local players = ComputerModServerPlayers.get()
    if not players then return end
    for i = 0, players:size() - 1 do
        sendServerCommand(players:get(i), "ComputerModChat", command, args or {})
    end
end

function ComputerModChatServer.sync(player)
    if player then
        ComputerModChatServer.sendSync(player)
    else
        ComputerModChatServer.broadcastSync()
    end
end

function ComputerModChatServer.reply(player, command, args)
    sendServerCommand(player, "ComputerModChat", command, args or {})
end

local function sendRecoveryMessage(username, recoveryEmail)
    local success, request = ComputerModAccountRecovery.request("chat", username, recoveryEmail)
    if not success then return false end
    local sent, message = ComputerModMail.sendMessage(
        "security@knoxnet.local",
        recoveryEmail,
        "KnoxChat password reset",
        "A password reset was requested for KnoxChat account " .. username .. ". Open this message and select Open reset link to choose a new password."
    )
    if not sent then return false end
    message.recoveryService = "chat"
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

function ComputerModChatServer.onInitGlobalModData(isNewGame)
    ComputerModChat.getStore()
end

function ComputerModChatServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModChat" then return end
    if ComputerModServerPlayers and ComputerModServerPlayers.markReady then ComputerModServerPlayers.markReady() end
    args = args or {}

    if command == "RequestSync" then
        ComputerModChatServer.sync(player)
        return
    end

    if command == "CreateAccount" then
        local recoveryEmail = ComputerModMail.normalizeAddress(args.recoveryEmail or "")
        local success, result = ComputerModChat.createAccount(args.username, args.password, recoveryEmail, recoveryEmail == "")
        if success then
            local normalized = ComputerModChat.normalizeUsername(args.username)
            ComputerModAccountSessions.authenticate("chat", player, normalized)
            ComputerModChatServer.broadcast("AccountUpsert", {username = normalized, account = ComputerModAccountSessions.publicCopy(result)})
            ComputerModChatServer.reply(player, "CreateResult", {success = true, username = normalized})
        else
            ComputerModChatServer.reply(player, "CreateResult", {success = false, reason = tostring(result or "invalid")})
        end
        return
    end

    if command == "Login" then
        local success, result = ComputerModChat.login(args.username, args.password)
        if success then
            local normalized = ComputerModChat.normalizeUsername(args.username)
            ComputerModAccountSessions.authenticate("chat", player, normalized)
            ComputerModChatServer.reply(player, "LoginResult", {success = true, username = normalized})
        else
            ComputerModChatServer.reply(player, "LoginResult", {success = false, reason = tostring(result or "missing")})
        end
        return
    end

    if command == "Logout" then
        ComputerModAccountSessions.clear("chat", player)
        return
    end

    if command == "RequestPasswordReset" then
        local username = ComputerModChat.normalizeUsername(args.username)
        local account = ComputerModChat.getAccount(username)
        local success = account and account.recoveryEmail and ComputerModMail.getAccount(account.recoveryEmail) and sendRecoveryMessage(username, account.recoveryEmail) or false
        ComputerModChatServer.reply(player, "RecoveryRequestResult", {success = success == true})
        return
    end

    if command == "ResetPassword" then
        local password = ComputerModChat.trim(args.password or "")
        if password == "" then
            ComputerModChatServer.reply(player, "PasswordResetResult", {success = false, reason = "password"})
            return
        end
        local authorized, username = ComputerModAccountRecovery.consume(player, args.requestId, "chat")
        local account = authorized and ComputerModChat.getAccount(username) or nil
        if not account then
            ComputerModChatServer.reply(player, "PasswordResetResult", {success = false, reason = tostring(username or "expired")})
            return
        end
        account.password = password
        ComputerModAccountSessions.clearAccount("chat", username)
        ComputerModAccountSessions.authenticate("chat", player, username)
        ComputerModChatServer.broadcast("AccountUpsert", {username = username, account = ComputerModAccountSessions.publicCopy(account)})
        ComputerModChatServer.reply(player, "PasswordResetResult", {success = true, username = username})
        return
    end

    if command == "SendRequest" then
        local fromUser = ComputerModAccountSessions.resolve("chat", player, args.fromUser, ComputerModChat.normalizeUsername)
        if not fromUser then
            ComputerModChatServer.reply(player, "RequestResult", {success = false, reason = "auth"})
            return
        end
        local success, reason = ComputerModChat.sendRequest(fromUser, args.toUser)
        if success then
            local toUser = ComputerModChat.normalizeUsername(args.toUser or "")
            ComputerModChatServer.broadcast("AccountUpsert", {username = fromUser, account = ComputerModAccountSessions.publicCopy(ComputerModChat.getAccount(fromUser))})
            ComputerModChatServer.broadcast("AccountUpsert", {username = toUser, account = ComputerModAccountSessions.publicCopy(ComputerModChat.getAccount(toUser))})
        end
        ComputerModChatServer.reply(player, "RequestResult", {success = success == true, reason = tostring(reason or "")})
        return
    end

    if command == "AcceptRequest" then
        local username = ComputerModAccountSessions.resolve("chat", player, args.username, ComputerModChat.normalizeUsername)
        if not username then
            ComputerModChatServer.reply(player, "AcceptResult", {success = false, reason = "auth", fromUser = ComputerModChat.normalizeUsername(args.fromUser or "")})
            return
        end
        local success, reason = ComputerModChat.acceptRequest(username, args.fromUser)
        if success then
            local fromUser = ComputerModChat.normalizeUsername(args.fromUser or "")
            ComputerModChatServer.broadcast("AccountUpsert", {username = username, account = ComputerModAccountSessions.publicCopy(ComputerModChat.getAccount(username))})
            ComputerModChatServer.broadcast("AccountUpsert", {username = fromUser, account = ComputerModAccountSessions.publicCopy(ComputerModChat.getAccount(fromUser))})
        end
        ComputerModChatServer.reply(player, "AcceptResult", {success = success == true, reason = tostring(reason or ""), fromUser = ComputerModChat.normalizeUsername(args.fromUser or "")})
        return
    end

    if command == "SendMessage" then
        local fromUser = ComputerModAccountSessions.resolve("chat", player, args.fromUser, ComputerModChat.normalizeUsername)
        if not fromUser then
            ComputerModChatServer.reply(player, "MessageResult", {success = false, reason = "auth", toUser = ComputerModChat.normalizeUsername(args.toUser or "")})
            return
        end
        local success, result = ComputerModChat.sendMessage(fromUser, args.toUser, args.body)
        if success then
            ComputerModChatServer.broadcast("MessageAdded", {
                fromUser = fromUser,
                toUser = ComputerModChat.normalizeUsername(args.toUser or ""),
                message = copyValue(result)
            })
        end
        ComputerModChatServer.reply(player, "MessageResult", {success = success == true, reason = success and "" or tostring(result or ""), toUser = ComputerModChat.normalizeUsername(args.toUser or "")})
        return
    end
end

Events.OnInitGlobalModData.Add(ComputerModChatServer.onInitGlobalModData)
Events.OnClientCommand.Add(ComputerModChatServer.onClientCommand)
