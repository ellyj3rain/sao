require "ComputerMod_Mail"

if isServer() then return end

ComputerModMailClient = ComputerModMailClient or {}

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

function ComputerModMailClient.applyStore(remoteStore)
    if type(remoteStore) ~= "table" then return end
    local store = ComputerModMail.getStore()
    for key in pairs(store) do
        store[key] = nil
    end
    for key, value in pairs(remoteStore) do
        store[key] = copyValue(value)
    end
end

function ComputerModMailClient.refreshUI()
    if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.currentView == "MAIL" and ComputerScreenUI.instance.setMailControlsVisible then
        ComputerScreenUI.instance:setMailControlsVisible(true)
    end
end

function ComputerModMailClient.applyMessageAdded(args)
    local address = ComputerModMail.normalizeAddress(args and args.address or "")
    local message = args and args.message or nil
    if address == "" or type(message) ~= "table" then return end
    local store = ComputerModMail.getStore()
    local account = store.accounts[address]
    if type(account) ~= "table" then
        account = {address = address, password = "", messages = {}}
        store.accounts[address] = account
    end
    if type(account.messages) ~= "table" then account.messages = {} end
    local messageId = tonumber(message.id or 0) or 0
    for i = 1, #account.messages do
        if tonumber(account.messages[i].id or 0) == messageId and messageId > 0 then return end
    end
    table.insert(account.messages, 1, copyValue(message))
    ComputerModMail.limitAccountMessages(account)
end

function ComputerModMailClient.applyAccountUpsert(args)
    local address = ComputerModMail.normalizeAddress(args and args.address or "")
    local account = args and args.account or nil
    if address == "" or type(account) ~= "table" then return end
    local store = ComputerModMail.getStore()
    store.accounts[address] = copyValue(account)
    ComputerModMail.limitAccountMessages(store.accounts[address])
end

function ComputerModMailClient.applyMessageDeleted(args)
    local account = ComputerModMail.getAccount(args and args.address or "")
    if not account or type(account.messages) ~= "table" then return end
    local messageId = tonumber(args and args.messageId or 0) or 0
    for i = #account.messages, 1, -1 do
        if tonumber(account.messages[i].id or 0) == messageId then
            table.remove(account.messages, i)
            return
        end
    end
end

function ComputerModMailClient.requestSync(playerObj)
    if isClient and isClient() and sendClientCommand then
        local player = playerObj or getPlayer and getPlayer() or nil
        if player then
            sendClientCommand(player, "ComputerModMail", "RequestSync", {})
        end
    end
end

function ComputerModMailClient.init()
    ComputerModMail.getStore()
    ComputerModMailClient.requestSync()
end

function ComputerModMailClient.onCreatePlayer(_, playerObj)
    ComputerModMailClient.requestSync(playerObj)
end

function ComputerModMailClient.onServerCommand(module, command, args)
    if module ~= "ComputerModMail" then return end
    args = args or {}
    if command == "Sync" then
        ComputerModMailClient.applyStore(args.store)
        ComputerModMailClient.refreshUI()
        return
    end
    if command == "MessageAdded" then
        ComputerModMailClient.applyMessageAdded(args)
        ComputerModMailClient.refreshUI()
        return
    end
    if command == "AccountUpsert" then
        ComputerModMailClient.applyAccountUpsert(args)
        ComputerModMailClient.refreshUI()
        return
    end
    if command == "MessageDeleted" then
        ComputerModMailClient.applyMessageDeleted(args)
        ComputerModMailClient.refreshUI()
        return
    end
    if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.handleMailServerCommand then
        ComputerScreenUI.instance:handleMailServerCommand(command, args)
    end
end

Events.OnInitGlobalModData.Add(ComputerModMailClient.init)
if Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(ComputerModMailClient.onCreatePlayer)
end
Events.OnServerCommand.Add(ComputerModMailClient.onServerCommand)
