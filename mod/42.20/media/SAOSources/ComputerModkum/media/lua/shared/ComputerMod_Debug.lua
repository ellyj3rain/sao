ComputerModDebug = ComputerModDebug or {}

function ComputerModDebug.isMultiplayer()
    local clientMode = isClient and isClient() or false
    local serverMode = isServer and isServer() or false
    return clientMode == true or serverMode == true
end

function ComputerModDebug.isAdmin(player)
    if not ComputerModDebug.isMultiplayer() then return true end
    local access = player and player.getAccessLevel and tostring(player:getAccessLevel() or "") or ""
    return string.lower(access) == "admin"
end

function ComputerModDebug.isEnabled(player)
    if not player or not player.getModData then return false end
    if not ComputerModDebug.isAdmin(player) then return false end
    local data = player:getModData()
    return data and data.ComputerModDebugEnabled == true
end

function ComputerModDebug.setEnabled(player, enabled)
    if not player or not player.getModData then return false end
    if not ComputerModDebug.isAdmin(player) then return false end
    local data = player:getModData()
    if not data then return false end
    data.ComputerModDebugEnabled = enabled == true
    if player.transmitModData then
        pcall(function() player:transmitModData() end)
    end
    return true
end
