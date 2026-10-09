ComputerModPosts = ComputerModPosts or {}

ComputerModPosts.storeName = "ComputerModPostsDB"

function ComputerModPosts.trim(value)
    value = tostring(value or "")
    value = string.gsub(value, "^%s+", "")
    value = string.gsub(value, "%s+$", "")
    return value
end

function ComputerModPosts.getStore()
    local store = ModData.getOrCreate(ComputerModPosts.storeName)
    if type(store.posts) ~= "table" then
        store.posts = {}
    end
    if type(store.nextPostId) ~= "number" then
        store.nextPostId = 1
    end
    return store
end

function ComputerModPosts.makeStamp()
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

function ComputerModPosts.addPost(name, body)
    local cleanName = ComputerModPosts.trim(name)
    local cleanBody = ComputerModPosts.trim(body)
    if cleanName == "" then cleanName = "Anonymous" end
    if cleanBody == "" then
        return false, "empty"
    end
    local store = ComputerModPosts.getStore()
    local id = tonumber(store.nextPostId or 1) or 1
    store.nextPostId = id + 1
    table.insert(store.posts, 1, {
        id = id,
        name = cleanName,
        body = cleanBody,
        stamp = ComputerModPosts.makeStamp()
    })
    while #store.posts > 40 do
        table.remove(store.posts)
    end
    return true, store.posts[1]
end
