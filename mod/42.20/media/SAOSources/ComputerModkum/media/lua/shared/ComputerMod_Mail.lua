ComputerModMail = ComputerModMail or {}

ComputerModMail.storeName = "ComputerModMailDB"
ComputerModMail.messageLimitVersion = 1
ComputerModMail.maxMessagesPerAccount = 150
ComputerModMail.maxSubjectLength = 120
ComputerModMail.maxBodyLength = 2000

function ComputerModMail.limitText(value, maxCharacters)
    local text = tostring(value or "")
    local limit = math.max(0, tonumber(maxCharacters or 0) or 0)
    if limit <= 0 or text == "" then return limit <= 0 and "" or text end
    local index = 1
    local count = 0
    local lastIndex = 0
    local length = string.len(text)
    while index <= length and count < limit do
        local byte = string.byte(text, index) or 0
        local width = 1
        if byte >= 240 then
            width = 4
        elseif byte >= 224 then
            width = 3
        elseif byte >= 192 then
            width = 2
        end
        if index + width - 1 > length then break end
        lastIndex = index + width - 1
        index = index + width
        count = count + 1
    end
    if index > length then return text end
    return string.sub(text, 1, lastIndex)
end

function ComputerModMail.limitAccountMessages(account)
    if type(account) ~= "table" then return end
    if type(account.messages) ~= "table" then account.messages = {} end
    for i = 1, #account.messages do
        local message = account.messages[i]
        if type(message) == "table" then
            message.subject = ComputerModMail.limitText(message.subject or "Mail", ComputerModMail.maxSubjectLength)
            message.body = ComputerModMail.limitText(message.body, ComputerModMail.maxBodyLength)
        end
    end
    while #account.messages > ComputerModMail.maxMessagesPerAccount do
        table.remove(account.messages)
    end
end

function ComputerModMail.trim(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

function ComputerModMail.normalizeAddress(address)
    return string.lower(ComputerModMail.trim(address))
end

function ComputerModMail.isValidAddress(address)
    local normalized = ComputerModMail.normalizeAddress(address)
    if normalized == "" then return false end
    if string.find(normalized, "%s") then return false end
    if not string.find(normalized, "@", 1, true) then return false end
    local user, domain = string.match(normalized, "^([^@]+)@([^@]+)$")
    if not user or not domain then return false end
    if user == "" or domain == "" then return false end
    return true
end

function ComputerModMail.getStore()
    local store = ModData.getOrCreate(ComputerModMail.storeName)
    if type(store.accounts) ~= "table" then
        store.accounts = {}
    end
    if type(store.nextMessageId) ~= "number" then
        store.nextMessageId = 1
    end
    if store.messageLimitVersion ~= ComputerModMail.messageLimitVersion then
        for _, account in pairs(store.accounts) do
            ComputerModMail.limitAccountMessages(account)
        end
        store.messageLimitVersion = ComputerModMail.messageLimitVersion
    end
    return store
end

function ComputerModMail.copyMessages(messages)
    local copy = {}
    if type(messages) ~= "table" then
        return copy
    end
    for i = 1, math.min(#messages, ComputerModMail.maxMessagesPerAccount) do
        local source = messages[i]
        if type(source) == "table" then
            copy[#copy + 1] = {
                id = tonumber(source.id or 0) or 0,
                from = tostring(source.from or ""),
                to = tostring(source.to or ""),
                subject = ComputerModMail.limitText(source.subject or "Mail", ComputerModMail.maxSubjectLength),
                body = ComputerModMail.limitText(source.body, ComputerModMail.maxBodyLength),
                stamp = tostring(source.stamp or ""),
                recoveryService = source.recoveryService and tostring(source.recoveryService) or nil,
                recoveryRequestId = source.recoveryRequestId and tostring(source.recoveryRequestId) or nil,
                recoveryUsername = source.recoveryUsername and tostring(source.recoveryUsername) or nil
            }
        end
    end
    return copy
end

function ComputerModMail.normalizeMessageIds(messages)
    if type(messages) ~= "table" then
        return messages
    end
    local store = ComputerModMail.getStore()
    local used = {}
    for i = 1, #messages do
        local entry = messages[i]
        if type(entry) == "table" then
            local id = tonumber(entry.id or 0) or 0
            if id > 0 then
                used[id] = true
                if id >= tonumber(store.nextMessageId or 1) then
                    store.nextMessageId = id + 1
                end
            end
        end
    end
    for i = 1, #messages do
        local entry = messages[i]
        if type(entry) == "table" then
            local id = tonumber(entry.id or 0) or 0
            if id <= 0 or used[id] == "dupe" then
                local nextId = ComputerModMail.nextMessageId()
                while used[nextId] do
                    nextId = ComputerModMail.nextMessageId()
                end
                entry.id = nextId
                used[nextId] = true
            elseif used[id] == true then
                used[id] = "dupe"
            end
        end
    end
    return messages
end

function ComputerModMail.makeStamp()
    if getGameTime then
        local ok, gameTime = pcall(getGameTime)
        if ok and gameTime then
            local month = 7
            local day = 1
            local hour = 12
            local minute = 0
            local okMonth, valueMonth = pcall(function() return gameTime:getMonth() end)
            local okDay, valueDay = pcall(function() return gameTime:getDay() end)
            local okHour, valueHour = pcall(function() return gameTime:getHour() end)
            local okMinute, valueMinute = pcall(function() return gameTime:getMinutes() end)
            if okMonth and valueMonth then month = math.floor(valueMonth) + 1 end
            if okDay and valueDay then day = math.floor(valueDay) + 1 end
            if okHour and valueHour then hour = math.floor(valueHour) end
            if okMinute and valueMinute then minute = math.floor(valueMinute) end
            return string.format("%02d/%02d %02d:%02d", day, month, hour, minute)
        end
    end
    return "00/00 00:00"
end

function ComputerModMail.getAccount(address)
    local normalized = ComputerModMail.normalizeAddress(address)
    if normalized == "" then return nil end
    local store = ComputerModMail.getStore()
    local account = store.accounts[normalized]
    if account and type(account.messages) == "table" then
        ComputerModMail.limitAccountMessages(account)
        ComputerModMail.normalizeMessageIds(account.messages)
    end
    return account
end

function ComputerModMail.ensureAccount(address, password, messages)
    local normalized = ComputerModMail.normalizeAddress(address)
    if not ComputerModMail.isValidAddress(normalized) then
        return false, "invalid"
    end
    local store = ComputerModMail.getStore()
    local account = store.accounts[normalized]
    if not account then
        account = {
            address = normalized,
            password = tostring(password or ""),
            messages = ComputerModMail.copyMessages(messages),
        }
        ComputerModMail.normalizeMessageIds(account.messages)
        store.accounts[normalized] = account
        return true, account, true
    end
    if (not account.password or account.password == "") and password and password ~= "" then
        account.password = tostring(password)
    end
    if type(account.messages) ~= "table" then
        account.messages = ComputerModMail.copyMessages(messages)
    end
    ComputerModMail.normalizeMessageIds(account.messages)
    return true, account, false
end

function ComputerModMail.createAccount(address, password)
    local normalized = ComputerModMail.normalizeAddress(address)
    password = ComputerModMail.trim(password)
    if not ComputerModMail.isValidAddress(normalized) then
        return false, "invalid"
    end
    if password == "" then
        return false, "password"
    end
    local store = ComputerModMail.getStore()
    if store.accounts[normalized] then
        return false, "exists"
    end
    store.accounts[normalized] = {
        address = normalized,
        password = password,
        messages = {}
    }
    return true, store.accounts[normalized]
end

function ComputerModMail.login(address, password)
    local normalized = ComputerModMail.normalizeAddress(address)
    password = ComputerModMail.trim(password)
    local account = ComputerModMail.getAccount(normalized)
    if not account then
        return false, "missing"
    end
    if tostring(account.password or "") ~= password then
        return false, "password"
    end
    return true, account
end

function ComputerModMail.nextMessageId()
    local store = ComputerModMail.getStore()
    local nextId = tonumber(store.nextMessageId or 1) or 1
    store.nextMessageId = nextId + 1
    return nextId
end

function ComputerModMail.sendMessage(fromAddress, toAddress, subject, body)
    local sender = ComputerModMail.normalizeAddress(fromAddress)
    local target = ComputerModMail.normalizeAddress(toAddress)
    subject = ComputerModMail.limitText(ComputerModMail.trim(subject), ComputerModMail.maxSubjectLength)
    body = ComputerModMail.limitText(body, ComputerModMail.maxBodyLength)
    if sender == "" or target == "" then
        return false, "missing"
    end
    if not ComputerModMail.isValidAddress(target) then
        return false, "invalid"
    end
    local recipient = ComputerModMail.getAccount(target)
    if not recipient then
        return false, "unknown"
    end
    if subject == "" then
        subject = "(No subject)"
    end
    if type(recipient.messages) ~= "table" then
        recipient.messages = {}
    end
    table.insert(recipient.messages, 1, {
        id = ComputerModMail.nextMessageId(),
        from = sender,
        to = target,
        subject = subject,
        body = body,
        stamp = ComputerModMail.makeStamp()
    })
    ComputerModMail.limitAccountMessages(recipient)
    return true, recipient.messages[1]
end

function ComputerModMail.deleteMessage(address, messageId)
    local account = ComputerModMail.getAccount(address)
    if not account or type(account.messages) ~= "table" then
        return false
    end
    local id = tonumber(messageId or 0) or 0
    for i = 1, #account.messages do
        if tonumber(account.messages[i].id or 0) == id then
            table.remove(account.messages, i)
            return true
        end
    end
    return false
end
