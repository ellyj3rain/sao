ComputerModAccountRecovery = ComputerModAccountRecovery or {}

ComputerModAccountRecovery.storeName = "ComputerModAccountRecoveryDB"
ComputerModAccountRecovery.expirationSeconds = 1800
ComputerModAccountRecovery.grants = ComputerModAccountRecovery.grants or {}

local function nowSeconds()
    if getTimestampMs then
        local ok, value = pcall(getTimestampMs)
        if ok and value then return math.floor((tonumber(value) or 0) / 1000) end
    end
    if os and os.time then
        local ok, value = pcall(os.time)
        if ok and value then return tonumber(value) or 0 end
    end
    return 0
end

local function playerKey(player)
    if player then return player end
    return "singleplayer"
end

function ComputerModAccountRecovery.getStore()
    local store = ModData.getOrCreate(ComputerModAccountRecovery.storeName)
    if type(store.requests) ~= "table" then store.requests = {} end
    if type(store.active) ~= "table" then store.active = {} end
    if type(store.nextRequestId) ~= "number" then store.nextRequestId = 1 end
    return store
end

function ComputerModAccountRecovery.cleanup()
    local store = ComputerModAccountRecovery.getStore()
    local current = nowSeconds()
    for requestId, request in pairs(store.requests) do
        if type(request) ~= "table" or request.used == true or (current > 0 and tonumber(request.expiresAt or 0) > 0 and current > tonumber(request.expiresAt or 0)) then
            if type(request) == "table" then
                local activeKey = tostring(request.service or "") .. ":" .. tostring(request.username or "")
                if store.active[activeKey] == requestId then store.active[activeKey] = nil end
            end
            store.requests[requestId] = nil
        end
    end
end

function ComputerModAccountRecovery.request(service, username, recoveryEmail)
    service = tostring(service or "")
    username = tostring(username or "")
    recoveryEmail = tostring(recoveryEmail or "")
    if (service ~= "chat" and service ~= "market") or username == "" or recoveryEmail == "" then
        return false, "invalid"
    end
    ComputerModAccountRecovery.cleanup()
    local store = ComputerModAccountRecovery.getStore()
    local activeKey = service .. ":" .. username
    local previousId = store.active[activeKey]
    if previousId then store.requests[previousId] = nil end
    local serial = tonumber(store.nextRequestId or 1) or 1
    store.nextRequestId = serial + 1
    local randomPart = ZombRand and ZombRand(100000, 999999) or serial * 7919
    local createdAt = nowSeconds()
    local requestId = tostring(createdAt) .. "-" .. tostring(serial) .. "-" .. tostring(randomPart)
    store.requests[requestId] = {
        id = requestId,
        service = service,
        username = username,
        recoveryEmail = recoveryEmail,
        createdAt = createdAt,
        expiresAt = createdAt > 0 and createdAt + ComputerModAccountRecovery.expirationSeconds or 0,
        used = false
    }
    store.active[activeKey] = requestId
    return true, store.requests[requestId]
end

function ComputerModAccountRecovery.authorize(player, requestId, recoveryEmail)
    ComputerModAccountRecovery.cleanup()
    local store = ComputerModAccountRecovery.getStore()
    local request = store.requests[tostring(requestId or "")]
    if not request or request.used == true then return false, "expired" end
    if tostring(request.recoveryEmail or "") ~= tostring(recoveryEmail or "") then return false, "auth" end
    ComputerModAccountRecovery.grants[playerKey(player)] = {
        requestId = tostring(request.id or ""),
        service = tostring(request.service or ""),
        username = tostring(request.username or "")
    }
    return true, request
end

function ComputerModAccountRecovery.consume(player, requestId, service)
    ComputerModAccountRecovery.cleanup()
    local key = playerKey(player)
    local grant = ComputerModAccountRecovery.grants[key]
    local normalizedId = tostring(requestId or "")
    local normalizedService = tostring(service or "")
    if not grant or grant.requestId ~= normalizedId or grant.service ~= normalizedService then
        return false, "auth"
    end
    local store = ComputerModAccountRecovery.getStore()
    local request = store.requests[normalizedId]
    if not request or request.used == true then
        ComputerModAccountRecovery.grants[key] = nil
        return false, "expired"
    end
    if tostring(request.service or "") ~= normalizedService or tostring(request.username or "") ~= tostring(grant.username or "") then
        ComputerModAccountRecovery.grants[key] = nil
        return false, "auth"
    end
    request.used = true
    local activeKey = normalizedService .. ":" .. tostring(request.username or "")
    if store.active[activeKey] == normalizedId then store.active[activeKey] = nil end
    store.requests[normalizedId] = nil
    ComputerModAccountRecovery.grants[key] = nil
    return true, tostring(request.username or "")
end
