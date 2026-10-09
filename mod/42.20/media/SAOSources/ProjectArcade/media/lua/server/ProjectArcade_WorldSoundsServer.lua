if not isServer() then return end

local PA_WS = {}
PA_WS.Active = {} -- key -> { x,y,z,sound,radius,volume,nextNoiseMs }

local function PA_IsAllowedSoundName(name)
    if not name or type(name) ~= "string" then return false end
    return name:sub(1,2) == "PA" or name:sub(1,3) == "PAM"
end

local function PA_ComputeNoiseParams(soundName)
    local radius = 20
    local volume = 50

    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if snd then
        local clip = snd:getRandomClip()
        if clip then
            if clip.getMaxDistance then
                local dmax = clip:getMaxDistance()
                if dmax and dmax > 0 then radius = math.floor(dmax) end
            end
            if clip.getVolume then
                local v = clip:getVolume()
                if v and v > 0 then volume = math.floor(math.min(100, v * 100)) end
            end
        end
    end

    return radius, volume
end

local function PA_BroadcastExcept(senderPlayer, command, data)
    local players = getOnlinePlayers()
    if not players then return end
    for i=0, players:size()-1 do
        local p = players:get(i)
        if p and p ~= senderPlayer then
            sendServerCommand(p, "ProjectArcade", command, data)
        end
    end
end

local function PA_AddWorldNoise(x,y,z, radius, volume)
    if addSound then
        addSound(nil, x, y, z, radius, volume)
    end
end

local function PA_NowMs()
    if getTimestampMs then return getTimestampMs() end
    return os.time() * 1000
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= "ProjectArcade" then return end
    if not args then return end

    if command == "WorldSoundStart" then
        local key = args.key
        local sound = args.sound
        local x,y,z = args.x, args.y, args.z
        if not key or not x or not y or z == nil then return end
        if not PA_IsAllowedSoundName(sound) then return end

        local radius, volume = PA_ComputeNoiseParams(sound)

        PA_WS.Active[key] = {
            x = x, y = y, z = z,
            sound = sound,
            radius = radius,
            volume = volume,
            nextNoiseMs = 0,
        }

        PA_BroadcastExcept(player, "WorldSoundStart", {
            key = key, x = x, y = y, z = z, sound = sound
        })

        PA_AddWorldNoise(x,y,z, radius, volume)
        return
    end

    if command == "WorldSoundStop" then
        local key = args.key
        if not key then return end

        PA_WS.Active[key] = nil

        PA_BroadcastExcept(player, "WorldSoundStop", { key = key })
        return
    end

    if command == "WorldSoundOneShot" then
        local key = args.key
        local sound = args.sound
        local x,y,z = args.x, args.y, args.z
        if not key or not x or not y or z == nil then return end
        if not PA_IsAllowedSoundName(sound) then return end

        local radius, volume = PA_ComputeNoiseParams(sound)

        PA_BroadcastExcept(player, "WorldSoundOneShot", {
            key = key, x = x, y = y, z = z, sound = sound
        })

        PA_AddWorldNoise(x,y,z, radius, volume)
        return
    end
end)

Events.OnTick.Add(function()
    local now = PA_NowMs()
    for key, v in pairs(PA_WS.Active) do
        if v and now >= (v.nextNoiseMs or 0) then
            PA_AddWorldNoise(v.x, v.y, v.z, v.radius or 20, v.volume or 50)
            v.nextNoiseMs = now + 2000
        end
    end
end)