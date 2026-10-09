require "ComputerMod_Chat"

if isServer() then return end

ComputerModChatClient = ComputerModChatClient or {}

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

function ComputerModChatClient.applyStore(remoteStore)
    if type(remoteStore) ~= "table" then return end
    local store = ComputerModChat.getStore()
    for key in pairs(store) do
        store[key] = nil
    end
    for key, value in pairs(remoteStore) do
        store[key] = copyValue(value)
    end
end

function ComputerModChatClient.refreshUI()
    if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.currentView == "CHAT" and ComputerScreenUI.instance.setChatControlsVisible then
        ComputerScreenUI.instance:setChatControlsVisible(true)
    end
end

local function addConversationMessage(account, partner, message)
    if not account or type(message) ~= "table" then return end
    ComputerModChat.ensureAccountShape(account)
    local conversation = ComputerModChat.getConversation(account, partner)
    local messageId = tonumber(message.id or 0) or 0
    for i = 1, #conversation do
        if tonumber(conversation[i].id or 0) == messageId and messageId > 0 then return end
    end
    conversation[#conversation + 1] = copyValue(message)
    ComputerModChat.limitConversation(conversation)
end

function ComputerModChatClient.applyMessageAdded(args)
    local fromUser = ComputerModChat.normalizeUsername(args and args.fromUser or "")
    local toUser = ComputerModChat.normalizeUsername(args and args.toUser or "")
    local message = args and args.message or nil
    if fromUser == "" or toUser == "" or type(message) ~= "table" then return end
    addConversationMessage(ComputerModChat.getAccount(fromUser), toUser, message)
    addConversationMessage(ComputerModChat.getAccount(toUser), fromUser, message)
end

function ComputerModChatClient.applyAccountUpsert(args)
    local username = ComputerModChat.normalizeUsername(args and args.username or "")
    local account = args and args.account or nil
    if username == "" or type(account) ~= "table" then return end
    local store = ComputerModChat.getStore()
    store.accounts[username] = copyValue(account)
    ComputerModChat.limitAccountData(store.accounts[username])
end

function ComputerModChatClient.requestSync(playerObj)
    if isClient and isClient() and sendClientCommand then
        local player = playerObj or getPlayer and getPlayer() or nil
        if player then
            sendClientCommand(player, "ComputerModChat", "RequestSync", {})
        end
    end
end

function ComputerModChatClient.init()
    ComputerModChat.getStore()
    ComputerModChatClient.requestSync()
end

function ComputerModChatClient.onCreatePlayer(_, playerObj)
    ComputerModChatClient.requestSync(playerObj)
end

function ComputerModChatClient.onServerCommand(module, command, args)
    if module ~= "ComputerModChat" then return end
    args = args or {}
    if command == "Sync" then
        ComputerModChatClient.applyStore(args.store)
        ComputerModChatClient.refreshUI()
        return
    end
    if command == "MessageAdded" then
        ComputerModChatClient.applyMessageAdded(args)
        ComputerModChatClient.refreshUI()
        return
    end
    if command == "AccountUpsert" then
        ComputerModChatClient.applyAccountUpsert(args)
        ComputerModChatClient.refreshUI()
        return
    end
    if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.handleChatServerCommand then
        ComputerScreenUI.instance:handleChatServerCommand(command, args)
    end
end

Events.OnInitGlobalModData.Add(ComputerModChatClient.init)
if Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(ComputerModChatClient.onCreatePlayer)
end
Events.OnServerCommand.Add(ComputerModChatClient.onServerCommand)
