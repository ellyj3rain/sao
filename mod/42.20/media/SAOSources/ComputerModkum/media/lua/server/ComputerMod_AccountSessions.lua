if not isServer() then return end

ComputerModAccountSessions = ComputerModAccountSessions or {}
ComputerModAccountSessions.sessions = ComputerModAccountSessions.sessions or {
    mail = {},
    chat = {},
    market = {}
}

local function getServiceSessions(service)
    local name = tostring(service or "")
    if type(ComputerModAccountSessions.sessions[name]) ~= "table" then
        ComputerModAccountSessions.sessions[name] = {}
    end
    return ComputerModAccountSessions.sessions[name]
end

function ComputerModAccountSessions.authenticate(service, player, account)
    local normalized = tostring(account or "")
    if not player or normalized == "" then return false end
    getServiceSessions(service)[player] = normalized
    return true
end

function ComputerModAccountSessions.get(service, player)
    if not player then return nil end
    return getServiceSessions(service)[player]
end

function ComputerModAccountSessions.resolve(service, player, claimedAccount, normalize)
    local authenticated = ComputerModAccountSessions.get(service, player)
    if not authenticated or authenticated == "" then return nil end
    local claimed = tostring(claimedAccount or "")
    if claimed ~= "" then
        if normalize then claimed = normalize(claimed) end
        if claimed ~= authenticated then return nil end
    end
    return authenticated
end

function ComputerModAccountSessions.clear(service, player)
    if not player then return end
    getServiceSessions(service)[player] = nil
end

function ComputerModAccountSessions.clearAccount(service, account)
    local normalized = tostring(account or "")
    if normalized == "" then return end
    local sessions = getServiceSessions(service)
    for player, authenticated in pairs(sessions) do
        if authenticated == normalized then sessions[player] = nil end
    end
end

function ComputerModAccountSessions.publicCopy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local copy = {}
    seen[value] = copy
    for key, nested in pairs(value) do
        if key ~= "password" and key ~= "recoveryEmail" then
            copy[ComputerModAccountSessions.publicCopy(key, seen)] = ComputerModAccountSessions.publicCopy(nested, seen)
        end
    end
    return copy
end
