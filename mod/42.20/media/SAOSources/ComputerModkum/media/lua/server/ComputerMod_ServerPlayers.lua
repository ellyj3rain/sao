ComputerModServerPlayers = ComputerModServerPlayers or {}
ComputerModServerPlayers.ready = ComputerModServerPlayers.ready == true

function ComputerModServerPlayers.markReady()
    ComputerModServerPlayers.ready = true
end

function ComputerModServerPlayers.get()
    if not isServer or not isServer() then return nil end
    if ComputerModServerPlayers.ready ~= true or not getOnlinePlayers then return nil end
    local ok, players = pcall(getOnlinePlayers)
    if not ok then return nil end
    return players
end

if isServer and isServer() and Events and Events.OnServerStarted and ComputerModServerPlayers.eventRegistered ~= true then
    Events.OnServerStarted.Add(ComputerModServerPlayers.markReady)
    ComputerModServerPlayers.eventRegistered = true
end
