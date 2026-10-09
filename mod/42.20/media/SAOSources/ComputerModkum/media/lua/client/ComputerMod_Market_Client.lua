require "ComputerMod_Market"

if isServer() then return end

ComputerModMarketClient = ComputerModMarketClient or {}

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

function ComputerModMarketClient.applyStore(remoteStore)
    if type(remoteStore) ~= "table" then return end
    local store = ComputerModMarket.getStore()
    for key in pairs(store) do
        store[key] = nil
    end
    for key, value in pairs(remoteStore) do
        store[key] = copyValue(value)
    end
end

function ComputerModMarketClient.requestSync(playerObj)
    if isClient and isClient() and sendClientCommand then
        local player = playerObj or getPlayer and getPlayer() or nil
        if player then
            sendClientCommand(player, "ComputerModMarket", "RequestSync", {})
        end
    end
end

function ComputerModMarketClient.init()
    ComputerModMarket.getStore()
    ComputerModMarketClient.requestSync()
end

function ComputerModMarketClient.onCreatePlayer(_, playerObj)
    ComputerModMarketClient.requestSync(playerObj)
end

function ComputerModMarketClient.onServerCommand(module, command, args)
    if module ~= "ComputerModMarket" then return end
    args = args or {}
    if command == "Sync" then
        ComputerModMarketClient.applyStore(args.store)
        if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.currentView == "MARKET" and ComputerScreenUI.instance.setMarketControlsVisible then
            ComputerScreenUI.instance:setMarketControlsVisible(true)
        end
        return
    end
    if ComputerScreenUI and ComputerScreenUI.instance and ComputerScreenUI.instance.handleMarketServerCommand then
        ComputerScreenUI.instance:handleMarketServerCommand(command, args)
    end
end

Events.OnInitGlobalModData.Add(ComputerModMarketClient.init)
if Events.OnCreatePlayer then
    Events.OnCreatePlayer.Add(ComputerModMarketClient.onCreatePlayer)
end
Events.OnServerCommand.Add(ComputerModMarketClient.onServerCommand)
