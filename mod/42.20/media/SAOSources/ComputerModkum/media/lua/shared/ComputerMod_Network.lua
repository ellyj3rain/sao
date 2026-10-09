ComputerModNetwork = ComputerModNetwork or {}

ComputerModNetwork.storeName = "ComputerModNetworkDB"

-- Kept in shared code so clients can identify relay objects before their
-- authoritative mod-data packet arrives on a multiplayer connection.
ComputerModNetwork.terminals = ComputerModNetwork.terminals or {
    {id = "muldraugh_mccoy", x = 10637, y = 10419, z = 1, label = "Muldraugh Police Relay"},
    {id = "riverside_police", x = 6087, y = 5248, z = 0, label = "Riverside Police Relay"},
    {id = "rosewood_fire", x = 8129, y = 11739, z = 0, label = "Rosewood Fire Relay"},
    {id = "westpoint_police", x = 11824, y = 6805, z = 1, label = "West Point Police Relay"},
    {id = "louisville_radio", x = 13565, y = 1586, z = 1, label = "KnoxTalk Radio Relay"},
    {id = "brandenburg_fire", x = 2062, y = 6262, z = 0, label = "Brandenburg Fire Relay"},
    {id = "echo_creek_service", x = 3575, y = 10897, z = -1, label = "Echo Creek Service Relay"},
    {id = "ekron_relay", x = 777, y = 9769, z = 0, label = "Ekron Relay"},
    {id = "irvington_gas", x = 2425, y = 13863, z = 0, label = "Irvington Gas Relay"}
}

function ComputerModNetwork.getTerminalById(terminalId)
    if not terminalId then return nil end
    for i = 1, #ComputerModNetwork.terminals do
        local terminal = ComputerModNetwork.terminals[i]
        if terminal.id == terminalId then return terminal end
    end
    return nil
end

function ComputerModNetwork.getTerminalForCoordinates(x, y, z)
    x, y, z = tonumber(x), tonumber(y), tonumber(z)
    if x == nil or y == nil or z == nil then return nil end
    local store = ComputerModNetwork.getStore()
    local terminalStores = store and store.terminals or nil
    for i = 1, #ComputerModNetwork.terminals do
        local terminal = ComputerModNetwork.terminals[i]
        local terminalStore = terminalStores and terminalStores[terminal.id] or nil
        local currentX = terminalStore and tonumber(terminalStore.currentX) or terminal.x
        local currentY = terminalStore and tonumber(terminalStore.currentY) or terminal.y
        local currentZ = terminalStore and tonumber(terminalStore.currentZ) or terminal.z
        if x == currentX and y == currentY and z == currentZ then
            return terminal
        end
    end
    return nil
end

function ComputerModNetwork.getTerminalForObject(object)
    if not object then return nil end
    local data = object.getModData and object:getModData() or nil
    local byId = data and ComputerModNetwork.getTerminalById(data.ComputerModNetworkTerminalId) or nil
    if byId then return byId end
    local square = object.getSquare and object:getSquare() or nil
    if not square then return nil end
    return ComputerModNetwork.getTerminalForCoordinates(square:getX(), square:getY(), square:getZ())
end

function ComputerModNetwork.getStore()
    local store = ModData.getOrCreate(ComputerModNetwork.storeName)
    if store.internetDisabled == nil then
        store.internetDisabled = false
    end
    if store.terminals == nil then
        store.terminals = {}
    end
    return store
end

function ComputerModNetwork.isInternetEnabled()
    if isClient and isClient() and ComputerModNetwork.clientInternetEnabled ~= nil then
        return ComputerModNetwork.clientInternetEnabled == true
    end
    local store = ComputerModNetwork.getStore()
    return store.internetDisabled ~= true
end

function ComputerModNetwork.setInternetEnabled(enabled)
    local store = ComputerModNetwork.getStore()
    store.internetDisabled = enabled ~= true
    if ModData and ModData.transmit then
        ModData.transmit(ComputerModNetwork.storeName)
    end
    return ComputerModNetwork.isInternetEnabled()
end

function ComputerModNetwork.getTerminalStore(terminalId)
    if not terminalId then return nil end
    local store = ComputerModNetwork.getStore()
    store.terminals = store.terminals or {}
    store.terminals[terminalId] = store.terminals[terminalId] or {}
    return store.terminals[terminalId]
end

function ComputerModNetwork.setActiveTerminal(terminalId)
    local store = ComputerModNetwork.getStore()
    store.activeTerminalId = terminalId
    if ModData and ModData.transmit then
        ModData.transmit(ComputerModNetwork.storeName)
    end
end
