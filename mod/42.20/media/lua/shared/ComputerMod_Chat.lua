-- Integrated source: ComputerModkum; original revision and terms in SAOSources manifest.
require "SAO_SourceIntegration"
if not SAO.SourceIntegration.active("ComputerModkum") then return end
require "ComputerMod_Mail"

ComputerModChat = ComputerModChat or {}

ComputerModChat.storeName = "ComputerModChatDB"
ComputerModChat.messageLimitVersion = 1
ComputerModChat.maxMessagesPerConversation = 250
ComputerModChat.maxMessageLength = 500
ComputerModChat.maxPendingRequests = 50

function ComputerModChat.limitText(value, maxCharacters)
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

function ComputerModChat.limitConversation(conversation)
    if type(conversation) ~= "table" then return end
    for i = #conversation, 1, -1 do
        if type(conversation[i]) ~= "table" then
            table.remove(conversation, i)
        end
    end
    while #conversation > ComputerModChat.maxMessagesPerConversation do
        table.remove(conversation, 1)
    end
end

function ComputerModChat.limitAccountData(account)
    if type(account) ~= "table" then return end
    if type(account.requests) ~= "table" then account.requests = {} end
    while #account.requests > ComputerModChat.maxPendingRequests do
        table.remove(account.requests)
    end
    if type(account.conversations) ~= "table" then account.conversations = {} end
    for _, conversation in pairs(account.conversations) do
        if type(conversation) == "table" then
            for i = 1, #conversation do
                local message = conversation[i]
                if type(message) == "table" then
                    message.body = ComputerModChat.limitText(message.body, ComputerModChat.maxMessageLength)
                end
            end
            ComputerModChat.limitConversation(conversation)
        end
    end
end

function ComputerModChat.trim(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

function ComputerModChat.normalizeUsername(username)
    return string.lower(ComputerModChat.trim(username))
end

function ComputerModChat.isValidUsername(username)
    local normalized = ComputerModChat.normalizeUsername(username)
    if normalized == "" then return false end
    if string.find(normalized, "%s") then return false end
    if string.find(normalized, "@", 1, true) then return false end
    if string.len(normalized) < 3 or string.len(normalized) > 32 then return false end
    return string.match(normalized, "^[%w%._%-]+$") ~= nil
end

function ComputerModChat.getStore()
    local store = ModData.getOrCreate(ComputerModChat.storeName)
    if type(store.accounts) ~= "table" then
        store.accounts = {}
    end
    if type(store.nextMessageId) ~= "number" then
        store.nextMessageId = 1
    end
    if store.messageLimitVersion ~= ComputerModChat.messageLimitVersion then
        for _, account in pairs(store.accounts) do
            ComputerModChat.limitAccountData(account)
        end
        store.messageLimitVersion = ComputerModChat.messageLimitVersion
    end
    return store
end

function ComputerModChat.makeStamp()
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

function ComputerModChat.nextMessageId()
    local store = ComputerModChat.getStore()
    local nextId = tonumber(store.nextMessageId or 1) or 1
    store.nextMessageId = nextId + 1
    return nextId
end

function ComputerModChat.getAccount(username)
    local normalized = ComputerModChat.normalizeUsername(username)
    if normalized == "" then return nil end
    local store = ComputerModChat.getStore()
    return store.accounts[normalized]
end

function ComputerModChat.ensureAccountShape(account)
    if not account then return nil end
    if type(account.contacts) ~= "table" then account.contacts = {} end
    if type(account.requests) ~= "table" then account.requests = {} end
    if type(account.conversations) ~= "table" then account.conversations = {} end
    return account
end

function ComputerModChat.createAccount(username, password, recoveryEmail, allowWithoutRecovery)
    local normalized = ComputerModChat.normalizeUsername(username)
    local displayName = ComputerModChat.trim(username)
    password = ComputerModChat.trim(password)
    recoveryEmail = ComputerModMail.normalizeAddress(recoveryEmail or "")
    if not ComputerModChat.isValidUsername(normalized) then
        return false, "invalid"
    end
    if password == "" then
        return false, "password"
    end
    if allowWithoutRecovery ~= true then
        if not ComputerModMail.isValidAddress(recoveryEmail) then
            return false, "mail"
        end
        if not ComputerModMail.getAccount(recoveryEmail) then
            return false, "mail"
        end
    end
    local store = ComputerModChat.getStore()
    if store.accounts[normalized] then
        return false, "exists"
    end
    local account = {
        username = normalized,
        displayName = displayName ~= "" and displayName or normalized,
        password = password,
        recoveryEmail = allowWithoutRecovery == true and nil or recoveryEmail,
        contacts = {},
        requests = {},
        conversations = {}
    }
    store.accounts[normalized] = account
    return true, account
end

function ComputerModChat.login(username, password)
    local normalized = ComputerModChat.normalizeUsername(username)
    local account = ComputerModChat.getAccount(normalized)
    if not account then
        return false, "missing"
    end
    if tostring(account.password or "") ~= ComputerModChat.trim(password) then
        return false, "password"
    end
    return true, ComputerModChat.ensureAccountShape(account)
end

function ComputerModChat.findRequestIndex(account, fromUser)
    if not account or type(account.requests) ~= "table" then return nil end
    local fromNormalized = ComputerModChat.normalizeUsername(fromUser)
    for i = 1, #account.requests do
        if ComputerModChat.normalizeUsername(account.requests[i].from or "") == fromNormalized then
            return i
        end
    end
    return nil
end

function ComputerModChat.hasContact(account, otherUser)
    if not account or type(account.contacts) ~= "table" then return false end
    return account.contacts[ComputerModChat.normalizeUsername(otherUser)] ~= nil
end

function ComputerModChat.sendRequest(fromUser, toUser)
    local fromNormalized = ComputerModChat.normalizeUsername(fromUser)
    local toNormalized = ComputerModChat.normalizeUsername(toUser)
    if not ComputerModChat.isValidUsername(fromNormalized) or not ComputerModChat.isValidUsername(toNormalized) then
        return false, "invalid"
    end
    if fromNormalized == toNormalized then
        return false, "self"
    end
    local sender = ComputerModChat.getAccount(fromNormalized)
    local recipient = ComputerModChat.getAccount(toNormalized)
    if not sender or not recipient then
        return false, "missing"
    end
    ComputerModChat.ensureAccountShape(sender)
    ComputerModChat.ensureAccountShape(recipient)
    if ComputerModChat.hasContact(sender, toNormalized) then
        return false, "contact"
    end
    if ComputerModChat.findRequestIndex(recipient, fromNormalized) then
        return false, "pending"
    end
    table.insert(recipient.requests, 1, {
        from = fromNormalized,
        displayName = tostring(sender.displayName or fromNormalized),
        stamp = ComputerModChat.makeStamp()
    })
    while #recipient.requests > ComputerModChat.maxPendingRequests do
        table.remove(recipient.requests)
    end
    return true
end

function ComputerModChat.acceptRequest(username, fromUser)
    local target = ComputerModChat.getAccount(username)
    local sender = ComputerModChat.getAccount(fromUser)
    if not target or not sender then
        return false, "missing"
    end
    ComputerModChat.ensureAccountShape(target)
    ComputerModChat.ensureAccountShape(sender)
    local requestIndex = ComputerModChat.findRequestIndex(target, fromUser)
    if not requestIndex then
        return false, "request"
    end
    table.remove(target.requests, requestIndex)
    local senderName = ComputerModChat.normalizeUsername(sender.username or fromUser)
    local targetName = ComputerModChat.normalizeUsername(target.username or username)
    target.contacts[senderName] = tostring(sender.displayName or senderName)
    sender.contacts[targetName] = tostring(target.displayName or targetName)
    target.conversations[senderName] = target.conversations[senderName] or {}
    sender.conversations[targetName] = sender.conversations[targetName] or {}
    return true
end

function ComputerModChat.getConversation(account, partner)
    account = ComputerModChat.ensureAccountShape(account)
    if not account then return {} end
    local partnerKey = ComputerModChat.normalizeUsername(partner)
    if partnerKey == "" then return {} end
    account.conversations[partnerKey] = account.conversations[partnerKey] or {}
    ComputerModChat.limitConversation(account.conversations[partnerKey])
    return account.conversations[partnerKey]
end

function ComputerModChat.sendMessage(fromUser, toUser, body)
    local fromAccount = ComputerModChat.getAccount(fromUser)
    local toAccount = ComputerModChat.getAccount(toUser)
    body = ComputerModChat.limitText(body, ComputerModChat.maxMessageLength)
    if not fromAccount or not toAccount then
        return false, "missing"
    end
    ComputerModChat.ensureAccountShape(fromAccount)
    ComputerModChat.ensureAccountShape(toAccount)
    local fromNormalized = ComputerModChat.normalizeUsername(fromUser)
    local toNormalized = ComputerModChat.normalizeUsername(toUser)
    if body == "" then
        return false, "body"
    end
    if not ComputerModChat.hasContact(fromAccount, toNormalized) or not ComputerModChat.hasContact(toAccount, fromNormalized) then
        return false, "contact"
    end
    local entry = {
        id = ComputerModChat.nextMessageId(),
        from = fromNormalized,
        to = toNormalized,
        body = body,
        stamp = ComputerModChat.makeStamp()
    }
    local fromConversation = ComputerModChat.getConversation(fromAccount, toNormalized)
    local toConversation = ComputerModChat.getConversation(toAccount, fromNormalized)
    fromConversation[#fromConversation + 1] = entry
    toConversation[#toConversation + 1] = entry
    ComputerModChat.limitConversation(fromConversation)
    ComputerModChat.limitConversation(toConversation)
    return true, entry
end
