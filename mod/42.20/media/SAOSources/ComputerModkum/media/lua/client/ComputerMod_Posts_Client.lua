require "ComputerMod_Posts"

if isServer() then return end

ComputerModPostsClient = ComputerModPostsClient or {}

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

function ComputerModPostsClient.applyStore(remoteStore)
    if type(remoteStore) ~= "table" then return end
    local store = ComputerModPosts.getStore()
    for key in pairs(store) do
        store[key] = nil
    end
    for key, value in pairs(remoteStore) do
        store[key] = copyValue(value)
    end
end

function ComputerModPostsClient.requestSync(playerObj)
    if isClient and isClient() and sendClientCommand then
        local player = playerObj or getPlayer and getPlayer() or nil
        if player then
            sendClientCommand(player, "ComputerModPosts", "RequestSync", {})
        end
    end
end

function ComputerModPostsClient.init()
    ComputerModPosts.getStore()
    ComputerModPostsClient.requestSync()
end

function ComputerModPostsClient.onCreatePlayer(_, playerObj)
    ComputerModPostsClient.requestSync(playerObj)
end

function ComputerModPostsClient.onServerCommand(module, command, args)
    if module ~= "ComputerModPosts" then return end
    args = args or {}
    if command == "Sync" then
        ComputerModPostsClient.applyStore(args.store)
        return
    end
    if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.handlePostsServerCommand then
        ComputerScreenUI.instance:handlePostsServerCommand(command, args)
    end
end

Events.OnInitGlobalModData.Add(ComputerModPostsClient.init)
if Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(ComputerModPostsClient.onCreatePlayer)
end
Events.OnServerCommand.Add(ComputerModPostsClient.onServerCommand)
