if not isClient() then return end

local PA_WS = {}
PA_WS.Active = {} -- key -> { emitter, soundId, sound, x,y,z, nextLoopAtMs }

local function PA_NowMs()
    if getTimestampMs then return getTimestampMs() end
    return os.time() * 1000
end

local function PA_StartLoop(key, soundName, x,y,z)
    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    -- Reusar entrada
    local e = PA_WS.Active[key]
    if not e then
        e = {}
        PA_WS.Active[key] = e
    end

    e.sound = soundName
    e.x, e.y, e.z = x,y,z

    if not e.emitter then
        e.emitter = IsoWorld.instance:getFreeEmitter()
    end
    e.emitter:setPos(x,y,z)

    e.soundId = nil
    e.nextLoopAtMs = 0
end

local function PA_StopLoop(key)
    local e = PA_WS.Active[key]
    if not e then return end
    if e.emitter and e.soundId and e.soundId ~= 0 then
        e.emitter:stopSound(e.soundId)
        e.emitter:tick()
    end
    PA_WS.Active[key] = nil
end

local function PA_PlayOneShot(soundName, x,y,z)
    local snd = GameSounds and GameSounds.getSound and GameSounds.getSound(soundName)
    if not snd then return end

    local clip = snd:getRandomClip()
    if not clip then return end

    local e = IsoWorld.instance:getFreeEmitter()
    e:setPos(x,y,z)

    local id = e:playClip(clip, nil)
    if id and id ~= 0 then
        local vol = (clip.getVolume and clip:getVolume()) or 1.0
        e:setVolume(id, vol)
        e:set3D(id, true)
        e:tick()
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= "ProjectArcade" then return end
    if not args then return end

    if command == "WorldSoundStart" then
        PA_StartLoop(args.key, args.sound, args.x, args.y, args.z)
        return
    end

    if command == "WorldSoundStop" then
        PA_StopLoop(args.key)
        return
    end

    if command == "WorldSoundOneShot" then
        PA_PlayOneShot(args.sound, args.x, args.y, args.z)
        return
    end
end)

Events.OnTick.Add(function()
    local now = PA_NowMs()
    for key, e in pairs(PA_WS.Active) do
        if e and e.sound and e.emitter then
            e.emitter:setPos(e.x, e.y, e.z)

            local shouldRestart = (not e.soundId or e.soundId == 0 or (e.nextLoopAtMs ~= 0 and now >= e.nextLoopAtMs))
            if shouldRestart then
                if e.soundId and e.soundId ~= 0 then
                    e.emitter:stopSound(e.soundId)
                    e.soundId = nil
                end

                local snd = GameSounds.getSound(e.sound)
                if snd then
                    local clip = snd:getRandomClip()
                    if clip then
                        e.soundId = e.emitter:playClip(clip, nil)
                        if e.soundId and e.soundId ~= 0 then
                            local dur = 60000
                            if getLoopDurationMs then dur = getLoopDurationMs(e.sound) or dur end
                            e.nextLoopAtMs = now + dur - 200

                            local vol = (clip.getVolume and clip:getVolume()) or 1.0
                            e.emitter:setVolume(e.soundId, vol)
                            e.emitter:set3D(e.soundId, true)
                        end
                    end
                end
            end

            e.emitter:tick()
        end
    end
end)