if not isServer() then return end

require "ComputerMod_Posts"
require "ComputerMod_ServerPlayers"

ComputerModPostsServer = ComputerModPostsServer or {}

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

function ComputerModPostsServer.sendSync(player)
    if player and sendServerCommand then
        sendServerCommand(player, "ComputerModPosts", "Sync", {store = copyValue(ComputerModPosts.getStore())})
    end
end

function ComputerModPostsServer.broadcastSync()
    local players = ComputerModServerPlayers.get()
    if not players then return end
    for i = 0, players:size() - 1 do
        ComputerModPostsServer.sendSync(players:get(i))
    end
end

function ComputerModPostsServer.sync(player)
    ModData.transmit(ComputerModPosts.storeName)
    if player then
        ComputerModPostsServer.sendSync(player)
    else
        ComputerModPostsServer.broadcastSync()
    end
end

function ComputerModPostsServer.reply(player, command, args)
    sendServerCommand(player, "ComputerModPosts", command, args or {})
end

function ComputerModPostsServer.onInitGlobalModData(isNewGame)
    ComputerModPosts.getStore()
end

function ComputerModPostsServer.onClientCommand(module, command, player, args)
    if module ~= "ComputerModPosts" then return end
    if ComputerModServerPlayers and ComputerModServerPlayers.markReady then ComputerModServerPlayers.markReady() end
    args = args or {}
    if command == "RequestSync" then
        ComputerModPostsServer.sync(player)
        return
    end
    if command == "AddPost" then
        local success = false
        local result = nil
        success, result = ComputerModPosts.addPost(args.name, args.body)
        if success then
            ComputerModPostsServer.sync()
            ComputerModPostsServer.reply(player, "AddPostResult", {success = true})
        else
            ComputerModPostsServer.reply(player, "AddPostResult", {success = false, reason = tostring(result or "empty")})
        end
    end
end

Events.OnInitGlobalModData.Add(ComputerModPostsServer.onInitGlobalModData)
Events.OnClientCommand.Add(ComputerModPostsServer.onClientCommand)
